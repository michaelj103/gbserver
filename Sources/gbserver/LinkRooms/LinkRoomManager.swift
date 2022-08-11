//
//  LinkRoomManager.swift
//
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation

class LinkRoomManager {
    static let sharedManager = LinkRoomManager()
    
    private var activeRooms = [String : LinkRoom]()
    private var expiredRooms = [String]()
    private var usersInRooms = Set<Int64>()
    private var activeOwnerKeys = [String : LinkRoom]()
    private var activeParticipantKeys = [String : LinkRoom]()
    private let queue = DispatchQueue(label: "LinkRoomManager")
    
    func runBlock(_ block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
    
    func createRoom(_ userID: Int64) throws -> LinkRoom {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard !usersInRooms.contains(userID) else {
            throw LinkRoomError.userAlreadyInRoom
        }
        
        let roomCode = KeyGenerator.generateKey(size: .init(bitCount: 32), encoding: .base32)
        guard activeRooms[roomCode] == nil else {
            // This should never happen. The keys should be securely generated and random 30-bit values
            // So technically there's a chance but if it ever occurs there's more likely a bug somewhere
            throw LinkRoomError.duplicateRoomCode
        }
        
        // create the room!
        let room = LinkRoom(roomCode, ownerID: userID)
        usersInRooms.insert(userID)
        activeRooms[roomCode] = room
        
        return room
    }
    
    func closeRoom(_ roomCode: String) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        
        guard let room = activeRooms[roomCode] else {
            throw LinkRoomError.roomNotFound
        }
        
        room.close()
        activeRooms[roomCode] = nil
        usersInRooms.remove(room.ownerID)
        if let participantID = room.participantID {
            usersInRooms.remove(participantID)
        }
        
        let maxExpiredRooms = 100
        expiredRooms.append(roomCode)
        if expiredRooms.count > maxExpiredRooms {
            let diff = expiredRooms.count - maxExpiredRooms
            expiredRooms.removeFirst(diff)
        }
    }
}

enum LinkRoomError: Error {
    case userAlreadyInRoom
    case duplicateRoomCode
    case roomNotFound
}
