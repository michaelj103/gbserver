//
//  HTTPSession.swift
//  
//
//  Created by Michael Brandt on 8/12/22.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOConcurrencyHelpers

class HTTPSession {
    private let threadGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    lazy private var bootstrap: ClientBootstrap = {
        ClientBootstrap(group: threadGroup)
            // Enable SO_REUSEADDR.
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMapThrowing { [weak self] _ -> HTTPConnection in
                    if let pendingConnection = self?.getConnection() {
                        return pendingConnection
                    } else {
                        throw SessionError.noPendingConnection
                    }
                }.flatMap { pendingConnection in
                    channel.pipeline.addHandler(HTTPRequestHandler(pendingConnection))
                }
            }
    }()
    
    private let host: String
    private let port: Int
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    private var connectionLock = Lock()
    private var pendingConnection: HTTPConnection? = nil
    private func getConnection() -> HTTPConnection? {
        connectionLock.withLock {
            self.pendingConnection
        }
    }
    
    func makeConnection() throws -> HTTPConnection {
        let connection = HTTPConnection()
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
        print("HTTPSession shutting down")
        try! threadGroup.syncShutdownGracefully()
    }
    
    // MARK: - Keep alive
    
    typealias VoidFunc = () -> Void
    private var keepAliveToken: VoidFunc?
    func keepAlive() {
        keepAliveToken = {
            self.stopKeepAlive()
        }
    }
    
    func stopKeepAlive() {
        self.keepAliveToken = nil
    }
    
    private enum SessionError: Error {
        case noPendingConnection
        case multiplePendingConnections
    }
}

// MARK: - Connection -

class HTTPConnection {
    private(set) var channel: Channel!
    private let queue = DispatchQueue(label: "HTTPConnectionQueue")
    
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
    typealias WriteCallback = (HTTPRequestHead, Data?) -> Void
    private var writeCallback: WriteCallback?
    func setWriteCallback(_ callback: WriteCallback?) {
        queue.sync { self.writeCallback = callback }
    }
    func write(header: HTTPRequestHead, body: Data?) {
        queue.async {
            self.writeCallback?(header, body)
        }
    }
}

fileprivate extension HTTPConnection {
    func setChannel(_ channel: Channel) {
        self.channel = channel
        
        channel.closeFuture.whenComplete { [weak self] result in
            self?.invokeCloseCallback(result)
        }
    }
}
