//
//  LinkRoomManager.swift
//
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import GBServerPayloads

class LinkRoomManager {
    static let sharedManager = LinkRoomManager()
    
    private var roomIDCounter = 0
    private var activeRooms = [String : LinkRoom]() // RoomCode : Room
    private var expiredRooms = [ExpiredLinkRoom]() // (RoomID, RoomCode) for lookup via either channel
    private var usersInRooms = [Int64 : String]() // UserID : RoomCode
    private var activeOwnerKeys = [String : String]() // Key : RoomCode
    private var activeParticipantKeys = [String : String]() // Key : RoomCode
    private let queue = DispatchQueue(label: "LinkRoomManager")
    
    func runBlock(_ block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
    
    private func _nextID() -> Int {
        let next = roomIDCounter
        roomIDCounter += 1
        return next
    }
    
    func createRoom(_ userID: Int64) throws -> LinkRoomClientInfo {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard usersInRooms[userID] == nil else {
            throw LinkRoomError.userAlreadyInRoom
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
        let room = LinkRoom(roomID, roomCode: roomCode, ownerID: userID)
        usersInRooms[userID] = roomCode
        activeRooms[roomCode] = room
        
        let keyString = KeyGenerator.generateKey(size: .bits128, encoding: .base64)
        activeOwnerKeys[keyString] = roomCode
        return LinkRoomClientInfo(roomID: roomID, roomCode: roomCode, roomKey: .owner(keyString))
    }
    
    // TODO: Server command for this
    func closeRoom(_ userID: Int64) throws {
        guard let roomCode = usersInRooms[userID] else {
            throw LinkRoomError.roomNotFound
        }
        
        try closeRoom(roomCode)
    }
    
    func closeRoom(_ roomCode: String) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard let room = activeRooms[roomCode] else {
            throw LinkRoomError.roomNotFound
        }
        
        room.close()
        activeRooms[roomCode] = nil
        usersInRooms[room.ownerID] = nil
        if let participantID = room.participantID {
            usersInRooms[participantID] = nil
        }
        
        let maxExpiredRooms = 100
        expiredRooms.append(ExpiredLinkRoom(roomID: room.roomID, roomCode: roomCode))
        if expiredRooms.count > maxExpiredRooms {
            let diff = expiredRooms.count - maxExpiredRooms
            expiredRooms.removeFirst(diff)
        }
    }
    
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
            key = .owner(keyString)
        }
        
        switch key {
        case .owner(let string):
            activeOwnerKeys[string] = roomCode
        case .participant(let string):
            activeParticipantKeys[string] = roomCode
        }
        
        return LinkRoomClientInfo(roomID: room.roomID, roomCode: room.roomCode, roomKey: key)
    }
    
    // TODO: Server command for this
    // Gets info for connecting to any active room that the user is currently a member of
    // Should never throw. If it does, indicates an internal state error
    func getCurrentRoom(_ userID: Int64) throws -> LinkRoomClientInfo? {
        let clientInfo: LinkRoomClientInfo?
        if let roomCode = usersInRooms[userID] {
            // "Join" the room. Should just generate fresh connection info since the user is already joined
            clientInfo = try joinRoom(userID, roomCode: roomCode)
        } else {
            clientInfo = nil
        }
        return clientInfo
    }
    
    private struct ExpiredLinkRoom {
        let roomID: Int
        let roomCode: String
    }
}

enum LinkRoomError: Error {
    case userAlreadyInRoom
    case duplicateRoomCode
    case roomNotFound
    case roomExpired
    case incorrectParticipant
}
