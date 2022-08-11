//
//  LinkRoom.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation

class LinkRoom {
    let roomCode: String
    let ownerID: Int64
    let participantID: Int64? = nil
    
    init(_ roomCode: String, ownerID: Int64) {
        self.roomCode = roomCode
        self.ownerID = ownerID
    }
    
    func close() {
        
    }
}
