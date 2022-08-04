//
//  File.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import NIOCore
import NIOPosix
import Dispatch

class XPCConnectionManager: XPCResponseHandlerDelegate {
    static private let unixDomainSocketPath = "/tmp/com.mjb.gbserver"
    private let threadGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    lazy private var bootstrap: ClientBootstrap = {
        ClientBootstrap(group: threadGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(XPCResponseDecoder())).flatMap { _ in
                    channel.pipeline.addHandler(XPCResponseHandler(self))
                }
            }
    }()
    
    deinit {
        try! threadGroup.syncShutdownGracefully()
    }
    
    private let sharedEncoder = JSONEncoder()
    private var activeConnection: XPCConnection?
    func makeConnection() throws -> XPCConnection {
        guard activeConnection == nil else {
            // Is there a reason to ever want more?
            throw XPCConnectionError("Only one connection allowed at a time")
        }
        
        let channel = try bootstrap.connect(unixDomainSocketPath: XPCConnectionManager.unixDomainSocketPath).wait()
        let connection = XPCConnection(channel, encoder: sharedEncoder)
        activeConnection = connection
        return connection
    }
    
    // MARK: - XPCResponseHandlerDelegate
    
    func handleSuccess(with data: Data) {
        self.activeConnection!._handleSuccess(with: data)
        self.activeConnection = nil
    }
    
    func handleError(with message: String) {
        self.activeConnection!._handleError(with: message)
        self.activeConnection = nil
    }
}

class XPCConnection {
    private let channel: Channel
    private let encoder: JSONEncoder
    init(_ channel: Channel, encoder: JSONEncoder = JSONEncoder()) {
        self.channel = channel
        self.encoder = encoder
    }
    
    private var responseHandler: ((Result<Data, Error>) -> ())?
    func sendRequest<T: XPCRequest>(_ request: T, responseHandler: @escaping (Result<Data,Error>)->()) throws {
        self.responseHandler = responseHandler
        var buffer = channel.allocator.buffer(capacity: 0)
        try request.encode(with: encoder, to: &buffer)
        try channel.writeAndFlush(buffer.slice()).wait()
        try channel.closeFuture.wait()
        self.responseHandler = nil
    }
}

fileprivate extension XPCConnection {
    func _handleSuccess(with data: Data) {
        let result: Result<Data,Error> = .success(data)
        responseHandler?(result)
    }
    
    func _handleError(with message: String) {
        let result: Result<Data,Error> = .failure(XPCConnectionError(message))
        responseHandler?(result)
    }
}

private struct XPCConnectionError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}
