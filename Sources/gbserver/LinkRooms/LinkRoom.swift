//
//  LinkRoom.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation

class LinkRoom {
    let roomID: Int
    let roomCode: String
    let ownerID: Int64
    private(set) var participantID: Int64? = nil
    
    init(_ id: Int, roomCode: String, ownerID: Int64) {
        self.roomID = id
        self.roomCode = roomCode
        self.ownerID = ownerID
    }
    
    func setParticipant(_ id: Int64) throws {
        guard participantID == nil else {
            throw RuntimeError("Tried to reset participant ID")
        }
        participantID = id
    }
    
    func close() {
        // probably dispatch_sync on internal queue
    }
}
