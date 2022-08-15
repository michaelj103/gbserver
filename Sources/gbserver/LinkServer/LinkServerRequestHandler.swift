//
//  LinkServerRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix

class LinkServerRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = LinkServerMessage
    public typealias OutboundOut = ByteBuffer
    
    private var connectionTimeout: Scheduled<Void>?
    private var connectedRoom: LinkRoom?
    
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
        print("Got message \(message)")
        var error: Error? = nil
        switch message {
        case .connect(let key):
            error = _runWithError {
                try _connectToRoom(context: context, key: key)
            }
        }
        
        if let error = error {
            print("Failure requiring room channel close: \(error)")
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
        let connectFuture = LinkRoomManager.sharedManager.runBlock(eventLoop: context.eventLoop) { manager -> LinkRoom in
            let (room, clientType) = try manager.roomForConnectionWithKey(key)
            try room.connectClient(channel: channel, clientType: clientType)
            return room
        }
        
        connectFuture.whenComplete { [weak self] result in
            self?._connectionDidComplete(context: context, result: result)
        }
    }
    
    private func _connectionDidComplete(context: ChannelHandlerContext, result: Result<LinkRoom, Error>) {
        switch result {
        case .success(let room):
            connectedRoom = room
        case .failure(let error):
            print("Failed to connect to a room with error \(error)")
            context.close(promise: nil)
        }
    }
    
    private enum ConnectionError: Error {
        case alreadyConnected
    }
}

