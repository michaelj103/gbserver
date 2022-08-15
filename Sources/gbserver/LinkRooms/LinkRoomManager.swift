//
//  LinkRoomManager.swift
//
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import GBServerPayloads
import NIOCore

class LinkRoomManager {
    static let sharedManager = LinkRoomManager()
    
    private let queue = DispatchQueue(label: "LinkRoomManager")
    private var roomIDCounter = 0
    private var activeRooms = [String : LinkRoom]() // RoomCode : Room
    private var expiredRooms = [ExpiredLinkRoom]() // (RoomID, RoomCode) for lookup via either channel
    private var usersInRooms = [Int64 : String]() // UserID : RoomCode
    
    // Key management
    private var allKeysByRoom = [String: Set<String>]() // RoomCode : Keys
    private var activeOwnerKeys = [String : String]() // Key : RoomCode
    private var activeParticipantKeys = [String : String]() // Key : RoomCode
    
    private var listeningPort: Int?
    private var nioState = LinkRoomManagerNIOState()
    
    func runBlock(_ block: @escaping (LinkRoomManager) -> Void) {
        queue.async {
            block(self)
        }
    }
    
    func setServerPort(_ port: Int) {
        listeningPort = port
    }
    
    private func _nextID() -> Int {
        let next = roomIDCounter
        roomIDCounter += 1
        return next
    }
    
    // MARK: - Creating rooms
    
    func createRoom(_ userID: Int64) throws -> LinkRoomClientInfo {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard usersInRooms[userID] == nil else {
            throw LinkRoomError.userAlreadyInRoom
        }
        
        guard let port = listeningPort else {
            throw LinkRoomError.linkServerNotRunning
        }
        
        let maxCodeAttempts = 5
        var attempts = 0
        var roomCode: String? = nil
        while attempts < maxCodeAttempts {
            attempts += 1
            let roomCodeCandidate = KeyGenerator.generateKey(size: .init(bitCount: 32), encoding: .base32)
            if activeRooms[roomCodeCandidate] == nil {
                roomCode = roomCodeCandidate
                break
            }
        }
        
        guard let roomCode = roomCode else {
            // This should never happen. The keys should be securely generated and random 30-bit values
            // So technically there's a chance but if it ever occurs there's more likely a bug somewhere
            throw LinkRoomError.duplicateRoomCode
        }
        
        // create the room!
        let roomID = _nextID()
        let room = LinkRoom(roomID, roomCode: roomCode, ownerID: userID) { [weak self] room in
            self?.runBlock { manager in
                manager._onQueue_roomDidClose(room)
            }
        }
        usersInRooms[userID] = roomCode
        activeRooms[roomCode] = room
        
        let keyString = KeyGenerator.generateKey(size: .bits128, encoding: .base64)
        _onQueue_addKey(.owner(keyString), roomCode: roomCode)
        return LinkRoomClientInfo(roomID: roomID, roomCode: roomCode, roomKey: .owner(keyString), linkPort: port)
    }
    
    // MARK: - Closing rooms
    
    // TODO: Server command for this
    // Close request from user with the given ID
    func closeRoom(_ userID: Int64) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let roomCode = usersInRooms[userID] else {
            throw LinkRoomError.roomNotFound
        }
        
        guard let room = activeRooms[roomCode] else {
            // This actually indicates a state management error. Users should not be marked as in a room if the room isn't active
            throw LinkRoomError.roomNotFound
        }
        
        guard room.ownerID == userID else {
            // Only the owner can request room closure
            throw LinkRoomError.mustBeRoomOwner
        }
        
        room.close(.userRequest)
    }
    
    private func _onQueue_roomDidClose(_ room: LinkRoom) {
        activeRooms[room.roomCode] = nil
        usersInRooms[room.ownerID] = nil
        if let participantID = room.participantID {
            usersInRooms[participantID] = nil
        }
        // remove all the keys for accessing this room
        _onQueue_removeKeys(room.roomCode)
        
        let maxExpiredRooms = 100
        expiredRooms.append(ExpiredLinkRoom(roomID: room.roomID, roomCode: room.roomCode))
        if expiredRooms.count > maxExpiredRooms {
            let diff = expiredRooms.count - maxExpiredRooms
            expiredRooms.removeFirst(diff)
        }
        
        if activeRooms.isEmpty {
            _onQueue_cancelRoomCleanupTask()
        }
    }
    
    // MARK: - Joining
    
    // Returns owner connection info to the owner
    // Returns participant connection info to a participant or first user with the code if participant is nil
    func joinRoom(_ userID: Int64, roomCode: String) throws -> LinkRoomClientInfo {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let room = activeRooms[roomCode] else {
            if expiredRooms.contains(where: { $0.roomCode == roomCode }) {
                throw LinkRoomError.roomExpired
            } else {
                throw LinkRoomError.roomNotFound
            }
        }
        
        guard let port = listeningPort else {
            throw LinkRoomError.linkServerNotRunning
        }
        
        // If the user is already in a room and it isn't this one, error
        // If they aren't in a room they'll join this one below
        // If they're in this room already, they'll get fresh connection info
        if let alreadyInRoom = usersInRooms[userID], alreadyInRoom != room.roomCode {
            throw LinkRoomError.userAlreadyInRoom
        }
        
        let key: LinkRoomKey
        if room.ownerID == userID {
            // The user is the owner
            let keyString = KeyGenerator.generateKey(size: .bits128, encoding: .base64)
            key = .owner(keyString)
        } else {
            if let existingParticipantID = room.participantID {
                // the room has already been claimed. Throw if it's not this user
                if userID != existingParticipantID {
                    throw LinkRoomError.incorrectParticipant
                }
            } else {
                // claim the particpant slot for this user
                try room.setParticipant(userID)
                usersInRooms[userID] = room.roomCode
            }
            
            // The user is the participant
            let keyString = KeyGenerator.generateKey(size: .bits128, encoding: .base64)
            key = .participant(keyString)
        }
        
        _onQueue_addKey(key, roomCode: roomCode)
        return LinkRoomClientInfo(roomID: room.roomID, roomCode: room.roomCode, roomKey: key, linkPort: port)
    }
    
    // TODO: Server command for this
    // Gets info for connecting to any active room that the user is currently a member of
    // Should never throw. If it does, indicates an internal state error
    func getCurrentRoom(_ userID: Int64) throws -> LinkRoomClientInfo? {
        dispatchPrecondition(condition: .onQueue(queue))
        let clientInfo: LinkRoomClientInfo?
        if let roomCode = usersInRooms[userID] {
            // "Join" the room. Should just generate fresh connection info since the user is already joined
            clientInfo = try joinRoom(userID, roomCode: roomCode)
        } else {
            clientInfo = nil
        }
        return clientInfo
    }
    
    // MARK: - Connecting
    
    func roomForConnectionWithKey(_ key: String) throws -> (LinkRoom, LinkRoom.ClientType) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let (roomCode, clientType) = _onQueue_useRoomKey(key) else {
            throw LinkRoomError.roomNotFound
        }
        guard let room = activeRooms[roomCode] else {
            throw LinkRoomError.roomNotFound
        }
        
        return (room, clientType)
    }
    
    
    // MARK: - Key management
    private func _onQueue_addKey(_ key: LinkRoomKey, roomCode: String) {
        switch key {
        case .owner(let keyString):
            activeOwnerKeys[keyString] = roomCode
            allKeysByRoom[roomCode, default: []].insert(keyString)
        case .participant(let keyString):
            activeParticipantKeys[keyString] = roomCode
            allKeysByRoom[roomCode, default: []].insert(keyString)
        }
    }
    
    // Remove all keys for a room, e.g. when closing
    private func _onQueue_removeKeys(_ roomCode: String) {
        if let allKeys = allKeysByRoom.removeValue(forKey: roomCode) {
            for key in allKeys {
                activeOwnerKeys.removeValue(forKey: key)
                activeParticipantKeys.removeValue(forKey: key)
            }
        }
    }
    
    private func _onQueue_useRoomKey(_ key: String) -> (String, LinkRoom.ClientType)? {
        let roomCode: String?
        let clientType: LinkRoom.ClientType?
        if let ownerRoomCode = activeOwnerKeys.removeValue(forKey: key) {
            roomCode = ownerRoomCode
            clientType = .owner
        } else if let participantRoomCode = activeParticipantKeys.removeValue(forKey: key) {
            roomCode = participantRoomCode
            clientType = .participant
        } else {
            roomCode = nil
            clientType = nil
        }
        if let roomCode = roomCode, let clientType = clientType {
            allKeysByRoom[roomCode]?.remove(key)
            return (roomCode, clientType)
        } else {
            return nil
        }
    }
        
    // MARK: - Types
    
    private struct ExpiredLinkRoom {
        let roomID: Int
        let roomCode: String
    }
}

enum LinkRoomError: Error {
    case userAlreadyInRoom
    case linkServerNotRunning
    case duplicateRoomCode
    case roomNotFound
    case roomExpired
    case incorrectParticipant
    case mustBeRoomOwner
}


// MARK: - NIO -

extension LinkRoomManager {
    private struct LinkRoomManagerNIOState {
        var roomCleanupTask: RepeatedTask?
    }
    
    func runBlock<T>(eventLoop: NIOCore.EventLoop, block: @escaping (LinkRoomManager) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        runBlock { manager in
            do {
                let result = try block(manager)
                promise.succeed(result)
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func ensureRoomCleanup(eventLoop: NIOCore.EventLoop) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard nioState.roomCleanupTask == nil else {
            // cleanup is already scheduled
            return
        }
        
        // Every 30 minutes, close inactive rooms
        let repeatedTask = eventLoop.scheduleRepeatedTask(initialDelay: .minutes(30), delay: .minutes(30)) { [weak self] _ in
            self?.runBlock({ manager in
                manager._onQueue_roomCleanupEventTriggered()
            })
        }
        
        nioState.roomCleanupTask = repeatedTask
    }
    
    private func _onQueue_roomCleanupEventTriggered() {
        for (_, room) in activeRooms {
            room.requireActivity()
        }
    }
    
    private func _onQueue_cancelRoomCleanupTask() {
        guard let task = nioState.roomCleanupTask else {
            return
        }
        
        task.cancel()
        nioState.roomCleanupTask = nil
    }
}
