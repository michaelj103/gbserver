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
    let closeHandler: (LinkRoom) -> Void
    private let queue: DispatchQueue
    private(set) var participantID: Int64? = nil
    
    init(_ id: Int, roomCode: String, ownerID: Int64, closeHandler: @escaping (LinkRoom) -> Void) {
        self.roomID = id
        self.roomCode = roomCode
        self.ownerID = ownerID
        self.closeHandler = closeHandler
        
        queue = DispatchQueue(label: "LinkRoom-\(id)")
    }
    
    func setParticipant(_ id: Int64) throws {
        try queue.sync {
            guard participantID == nil else {
                throw RuntimeError("Tried to reset participant ID")
            }
            participantID = id
            noteActivity()
        }
    }
    
    func close(_ reason: RoomCloseReason) {
        queue.sync {
            _onQueue_close(reason)
        }
    }
    
    private var closed = false
    private func _onQueue_close(_ reason: RoomCloseReason) {
        if self.closed {
            return
        }
        self.closed = true
        print("Closing room \(self.roomID) for reason: \(reason))")
        self.closeHandler(self)
    }
    
    // MARK: - Tracking room inactivity
    
    private var isActive = true
    private func noteActivity() {
        isActive = true
    }
    
    func requireActivity() {
        queue.async {
            // close unless the room was active within the last requirement period
            let wasActive = self.isActive
            self.isActive = false
            if !wasActive {
                self._onQueue_close(.inactive)
            }
        }
    }
    
    enum RoomCloseReason {
        case userRequest
        case inactive
        case error(Error)
    }
}
