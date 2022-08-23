//
//  LinkClientSession.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

public class LinkClientSession {
    private let threadGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    lazy private var bootstrap: ClientBootstrap = {
        ClientBootstrap(group: threadGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .channelInitializer { [weak self] channel in
                if let pendingConnection = self?.getConnection() {
                    return channel.pipeline.addHandler(ByteToMessageHandler(LinkClientMessageDecoder())).flatMap { _ in
                        channel.pipeline.addHandler(LinkClientHandler(pendingConnection))
                    }
                } else {
                    return channel.eventLoop.makeFailedFuture(SessionError.noPendingConnection)
                }
            }
    }()
    
    private let host: String
    private let port: Int
    private let sessionID: UUID
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
        sessionID = UUID()
    }
    
    private var connectionLock = Lock()
    private var pendingConnection: LinkClientConnection? = nil
    private func getConnection() -> LinkClientConnection? {
        connectionLock.withLock {
            self.pendingConnection
        }
    }
    
    public func makeConnection() throws -> LinkClientConnection {
        let connection = LinkClientConnection()
        try connectionLock.withLockVoid {
            guard pendingConnection == nil else {
                throw SessionError.multiplePendingConnections
            }
            pendingConnection = connection
        }
        
        let channel = try bootstrap.connect(host: host, port: port).wait()
        connection.setChannel(channel)
        connectionLock.withLockVoid {
            pendingConnection = nil
        }
        return connection
    }
    
    deinit {
        print("LinkClientSession shutting down")
        try! threadGroup.syncShutdownGracefully()
    }
    
    // MARK: - Keep alive
    
    private static var keepAliveSessions = [UUID: LinkClientSession]()
    public func keepAlive() {
        LinkClientSession.keepAliveSessions[sessionID] = self
    }
    
    public func stopKeepAlive() {
        LinkClientSession.keepAliveSessions[sessionID] = nil
    }
    
    private enum SessionError: Error {
        case noPendingConnection
        case multiplePendingConnections
    }
}

// MARK: - Connection -

public class LinkClientConnection {
    private(set) var channel: Channel!
    private let queue = DispatchQueue(label: "LinkClientConnectionQueue")
    
    public func close() {
        channel.close(mode: .all, promise: nil)
    }
    
    // MARK: - Connection state
    
    public typealias CloseCallback = (Result<Void, Error>) -> Void
    private var closeCallback: CloseCallback?
    public func setCloseCallback(_ callback: CloseCallback?) {
        queue.sync { self.closeCallback = callback }
    }
    private func invokeCloseCallback(_ result: Result<Void,Error>) {
        queue.async {
            self.closeCallback?(result)
        }
    }
    
    // MARK: - Reading data
    
    public typealias MessageReadCallback = (LinkClientMessage) -> Void
    private var messageCallback: MessageReadCallback?
    public func setMessageCallback(_ callback: MessageReadCallback?) {
        queue.sync { self.messageCallback = callback }
    }
    internal func handleRead(_ message: LinkClientMessage) {
        queue.async {
            self.messageCallback?(message)
        }
    }
    
    // MARK: - Writing data
    public func write(_ bytes: [UInt8]) {
        queue.async {
            var buffer = self.channel.allocator.buffer(capacity: bytes.count)
            buffer.writeBytes(bytes)
            let _ = self.channel.writeAndFlush(buffer.slice())
        }
    }
}

fileprivate extension LinkClientConnection {
    func setChannel(_ channel: Channel) {
        queue.sync {
            self.channel = channel
            
            channel.closeFuture.whenComplete { [weak self] result in
                self?.invokeCloseCallback(result)
            }
        }
    }
}

