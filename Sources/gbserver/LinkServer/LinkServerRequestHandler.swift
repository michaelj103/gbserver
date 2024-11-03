//
//  LinkServerRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix
import GBLinkServerProtocol

class LinkServerRequestHandler: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = LinkServerMessage
    public typealias OutboundOut = ByteBuffer
    
    private var connectionTimeout: Scheduled<Void>?
    private var connectedRoom: LinkRoom?
    private var connectedType: LinkRoom.ClientType?
    
    public func handlerAdded(context: ChannelHandlerContext) {
        let timeout: Scheduled<Void> = context.eventLoop.scheduleTask(in: .seconds(10)) { [weak self] in
            self?._connectionTimeLimitExceeded(context: context)
        }
        connectionTimeout = timeout
    }
    
    private func _connectionTimeLimitExceeded(context: ChannelHandlerContext) {
        print("Connection timeout")
        context.close(promise: nil)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = unwrapInboundIn(data)
//        print("Received message \(message)")
        var error: Error? = nil
        switch message {
        case .connect(let key):
            error = _runWithError {
                try _connectToRoom(context: context, key: key)
            }
        case .initialByte(let byte):
            error = _runWithError {
                try _handleInitialByte(byte)
            }
        case .pushByte(let byte):
            error = _runWithError {
                try _handlePushedByte(byte)
            }
        case .presentByte(let byte):
            error = _runWithError {
                try _handlePresentedByte(byte)
            }
        }
        
        if let error = error {
            print("Failure requiring room channel close: \(error)")
            context.close(promise: nil)
        }
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
    
    private func _runWithError(_ block: () throws -> ()) -> Error? {
        do {
            try block()
            return nil
        } catch {
            return error
        }
    }
    
    private func _connectToRoom(context: ChannelHandlerContext, key: String) throws {
        guard connectedRoom == nil else {
            throw ConnectionError.alreadyConnected
        }
        
        // First cancel the timeout
        connectionTimeout?.cancel()
        connectionTimeout = nil
        
        let channel = context.channel
        let connectFuture = LinkRoomManager.sharedManager.runBlock(eventLoop: context.eventLoop) { manager -> (LinkRoom, LinkRoom.ClientType) in
            let (room, clientType) = try manager.roomForConnectionWithKey(key)
            try room.connectClient(channel: channel, clientType: clientType)
            return (room, clientType)
        }
        
        connectFuture.whenComplete { [weak self] result in
            self?._connectionDidComplete(context: context, result: result)
        }
    }
    
    private func _connectionDidComplete(context: ChannelHandlerContext, result: Result<(LinkRoom, LinkRoom.ClientType), Error>) {
        switch result {
        case .success(let (room, clientType)):
            connectedRoom = room
            connectedType = clientType
            let buffer = ByteBuffer(bytes: [LinkClientCommand.didConnect.rawValue])
            context.channel.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
            
        case .failure(let error):
            print("Failed to connect to a room with error \(error)")
            context.close(promise: nil)
        }
    }
    
    private func _handleInitialByte(_ byte: UInt8) throws {
        guard let connectedRoom = connectedRoom, let clientType = connectedType else {
            throw ConnectionError.dataReceivedWithoutConnection
        }
        
        connectedRoom.clientInitialByte(byte, clientType: clientType)
    }
    
    private func _handlePushedByte(_ byte: UInt8) throws {
        guard let connectedRoom = connectedRoom, let clientType = connectedType else {
            throw ConnectionError.dataReceivedWithoutConnection
        }
        
        connectedRoom.clientPushByte(byte, clientType: clientType)
    }
    
    private func _handlePresentedByte(_ byte: UInt8) throws {
        guard let connectedRoom = connectedRoom, let clientType = connectedType else {
            throw ConnectionError.dataReceivedWithoutConnection
        }
        
        connectedRoom.clientPresentByte(byte, clientType: clientType)
    }
    
    private enum ConnectionError: Error {
        case alreadyConnected
        case dataReceivedWithoutConnection
    }
}

