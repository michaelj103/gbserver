//
//  LinkRoom.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import NIOCore
import GBLinkServerProtocol

class LinkRoom {
    let roomID: Int
    let roomCode: String
    let ownerID: Int64
    let closeHandler: (LinkRoom) -> Void
    private let queue: DispatchQueue
    private(set) var participantID: Int64? = nil
    
    private var ownerChannel: Channel?
    private var participantChannel: Channel?
    
    init(_ id: Int, roomCode: String, ownerID: Int64, closeHandler: @escaping (LinkRoom) -> Void) {
        self.roomID = id
        self.roomCode = roomCode
        self.ownerID = ownerID
        self.closeHandler = closeHandler
        
        queue = DispatchQueue(label: "LinkRoom-\(id)")
    }
    
    // MARK: - Room Manager Interface
    
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
        ownerChannel?.close(mode: .all, promise: nil)
        participantChannel?.close(mode: .all, promise: nil)
        print("Closing room \(self.roomID) for reason: \(reason)")
        self.closeHandler(self)
    }
    
    // MARK: - Connection Interface
    
    func connectClient(channel: Channel, clientType: ClientType) throws {
        try queue.sync {
            switch clientType {
            case .owner:
                try _onQueue_connectOwner(channel)
            case .participant:
                try _onQueue_connectParticipant(channel)
            }
        }
    }
    
    private func _onQueue_connectOwner(_ channel: Channel) throws {
        guard ownerChannel == nil else {
            throw RoomError.ownerAlreadyConnected
        }
        print("Owner joined")
        ownerChannel = channel
        channel.closeFuture.whenComplete { [weak self] _ in
            print("Owner disconnected")
            self?.ownerChannel = nil
        }
    }
    
    private func _onQueue_connectParticipant(_ channel: Channel) throws {
        guard participantChannel == nil else {
            throw RoomError.participantAlreadyConnected
        }
        participantChannel = channel
        print("Participant joined")
        channel.closeFuture.whenComplete { [weak self] _ in
            print("Participant disconnected")
            self?.participantChannel = nil
        }
    }
    
    // MARK: - Client Data I/O
    
    private var ownerState = ClientState.idle(0xFF)
    private var participantState = ClientState.idle(0xFF)
    
    func clientInitialByte(_ byte: UInt8, clientType: ClientType) {
        queue.sync {
            noteActivity()
            
            switch clientType {
            case .owner:
                ownerState = .idle(byte)
            case .participant:
                participantState = .idle(byte)
            }
        }
    }
    
    func clientPushByte(_ byte: UInt8, clientType: ClientType) {
        queue.sync {
            noteActivity()
            
            switch clientType {
            case .owner:
                if let participantChannel = participantChannel {
                    // participant is connected, run the push logic
                    _onQueue_clientPush(byte, fromState: &ownerState, fromChannel: ownerChannel!, toState: &participantState, toChannel: participantChannel)
                } else {
                    // participant is not connected, respond to owner with not-connected byte
                    ownerChannel?.sendLinkMessage(.pullByte(0xFF))
                    ownerState = .idle(0xFF)
                }
            case .participant:
                if let ownerChannel = ownerChannel {
                    // owner is connected, run the push logic
                    _onQueue_clientPush(byte, fromState: &participantState, fromChannel: participantChannel!, toState: &ownerState, toChannel: ownerChannel)
                } else {
                    // owner is not connected, respond to participant with not-connected byte
                    participantChannel?.sendLinkMessage(.pullByte(0xFF))
                    participantState = .idle(0xFF)
                }
            }
        }
    }
    
    private func _onQueue_clientPush(_ byte: UInt8, fromState: inout ClientState, fromChannel: Channel, toState: inout ClientState, toChannel: Channel) {
        
        switch toState {
        case .idle(_):
            // Push when the "to" side hasn't prepped a byte to exchange. Just wait
            fromState = .pushed(byte)
            
        case .presented(let presentedByte):
            // Happy path: the "to" side has already presented, so we can do the swap normally
            let newToSideByte = byte
            let newFromSideByte = presentedByte
            
            // Normal with "from" pushing
            toChannel.sendLinkMessage(.bytePushed(newToSideByte))
            fromChannel.sendLinkMessage(.pullByte(newFromSideByte))
            
            toState = .idle(newToSideByte)
            fromState = .idle(newFromSideByte)
            
        case .pushed(let otherPushedByte):
            // The "to" side was waiting for a push response and the "from" side pushed
            // We have a few options for how this *could* be handled but it's really a client issue
            // Going with: complete the exchange as normal with both sides "pulling"
            let newToSideByte = byte
            let newFromSideByte = otherPushedByte
            
            toChannel.sendLinkMessage(.pullByte(newToSideByte))
            fromChannel.sendLinkMessage(.pullByte(newFromSideByte))
            
            toState = .idle(newToSideByte)
            fromState = .idle(newFromSideByte)
        }
    }
    
    func clientPresentByte(_ byte: UInt8, clientType: ClientType) {
        queue.sync {
            noteActivity()
            
            switch clientType {
            case .owner:
                if let participantChannel = participantChannel {
                    // participant is connected, run the present logic
                    _onQueue_clientPresent(byte, fromState: &ownerState, fromChannel: ownerChannel!, toState: &participantState, toChannel: participantChannel)
                } else {
                    // participant is not connected. Fall into the "presented" state
                    ownerState = .presented(byte)
                }
            case .participant:
                if let ownerChannel = ownerChannel {
                    // owner is connected, run the present logic
                    _onQueue_clientPresent(byte, fromState: &participantState, fromChannel: participantChannel!, toState: &ownerState, toChannel: ownerChannel)
                } else {
                    // owner is not connected. Fall into the "presented" state
                    participantState = .presented(byte)
                }
            }
        }
    }
    
    private func _onQueue_clientPresent(_ byte: UInt8, fromState: inout ClientState, fromChannel: Channel, toState: inout ClientState, toChannel: Channel) {
        
        switch toState {
        case .idle(_), .presented(_):
            // Other side isn't trying to do anything, so just sit here
            fromState = .presented(byte)
        case .pushed(let pushedByte):
            // Other side pushed ahead of this presentation. Send them the new byte and push back to us
            // Assume that this is the happy path with a slight timing offset and do a normal exchange
            let newToSideByte = byte
            let newFromSideByte = pushedByte
            
            // Normal with "to" pushing
            toChannel.sendLinkMessage(.pullByte(byte))
            fromChannel.sendLinkMessage(.bytePushed(newFromSideByte))
            
            toState = .idle(newToSideByte)
            fromState = .idle(newFromSideByte)
        }
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
    
    enum ClientType {
        case owner
        case participant
    }
    
    enum RoomError: Error {
        case ownerAlreadyConnected
        case participantAlreadyConnected
    }
    
    private enum ClientState {
        /// Not waiting for anything to happen with argument byte in register
        case idle(UInt8)
        
        /// Client has presented the given byte for pull and is waiting for the other client to push
        case presented(UInt8)
        
        /// Client has pushed the given byte (first arg) and the other client didn't have a byte presented
        case pushed(UInt8)
    }
}

// Channel extension for sending messages to clients
extension Channel {
    @discardableResult
    func sendLinkMessage(_ message: LinkClientMessage) -> EventLoopFuture<Void> {
        var buffer = allocator.buffer(capacity: 2)
        switch message {
        case .didConnect:
            // never sent from here
            return eventLoop.makeSucceededVoidFuture()
        case .pullByte(let byte):
            buffer.writeBytes([LinkClientCommand.pullByte.rawValue, byte])
        case .pullByteStale(let byte):
            buffer.writeBytes([LinkClientCommand.pullByteStale.rawValue, byte])
        case .commitStaleByte:
            buffer.writeBytes([LinkClientCommand.commitStaleByte.rawValue])
        case .bytePushed(let byte):
            buffer.writeBytes([LinkClientCommand.bytePushed.rawValue, byte])
        }
        
        let future = writeAndFlush(buffer)
        return future
    }
}
