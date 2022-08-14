//
//  LinkClientSession.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOConcurrencyHelpers

class LinkClientSession {
    private let threadGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    lazy private var bootstrap: ClientBootstrap = {
        ClientBootstrap(group: threadGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { [weak self] channel in
                if let pendingConnection = self?.getConnection() {
                    return channel.pipeline.addHandler(LinkClientHandler(pendingConnection))
                } else {
                    return channel.eventLoop.makeFailedFuture(SessionError.noPendingConnection)
                }
            }
    }()
    
    private let host: String
    private let port: Int
    private let sessionID: UUID
    init(host: String, port: Int) {
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
    
    func makeConnection() throws -> LinkClientConnection {
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
    
    static var keepAliveSessions = [UUID: LinkClientSession]()
    func keepAlive() {
        LinkClientSession.keepAliveSessions[sessionID] = self
    }
    
    func stopKeepAlive() {
        LinkClientSession.keepAliveSessions[sessionID] = nil
    }
    
    private enum SessionError: Error {
        case noPendingConnection
        case multiplePendingConnections
    }
}

// MARK: - Connection -

class LinkClientConnection {
    private(set) var channel: Channel!
    private let queue = DispatchQueue(label: "LinkClientConnectionQueue")
    
    // MARK: - Connection state
    
    typealias CloseCallback = (Result<Void, Error>) -> Void
    private var closeCallback: CloseCallback?
    func setCloseCallback(_ callback: CloseCallback?) {
        queue.sync { self.closeCallback = callback }
    }
    private func invokeCloseCallback(_ result: Result<Void,Error>) {
        queue.async {
            self.closeCallback?(result)
        }
    }
    
    // MARK: - Reading data
    
    typealias BodyDataCallback = (Data) -> Void
    private var bodyDataCallback: BodyDataCallback?
    func setBodyDataCallback(_ callback: BodyDataCallback?) {
        queue.sync { self.bodyDataCallback = callback }
    }
    func handleRead(_ data: Data) {
        queue.async {
            self.bodyDataCallback?(data)
        }
    }
    
    typealias BodyTextCallback = (String) -> Void
    private var bodyTextCallback: BodyTextCallback?
    func setBodyTextCallback(_ callback: BodyTextCallback?) {
        queue.sync { self.bodyTextCallback = callback }
    }
    func handleRead(_ text: String) {
        queue.async {
            self.bodyTextCallback?(text)
        }
    }
    
    // MARK: - Writing data
    func write(_ bytes: [UInt8]) {
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        let _ = channel.writeAndFlush(buffer.slice())
    }
}

fileprivate extension LinkClientConnection {
    func setChannel(_ channel: Channel) {
        self.channel = channel
        
        channel.closeFuture.whenComplete { [weak self] result in
            self?.invokeCloseCallback(result)
        }
    }
}

