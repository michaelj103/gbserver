//
//  HTTPServer.swift
//  
//
//  Created by Michael Brandt on 7/31/22.
//

import NIOCore
import NIOHTTP1
import NIOPosix
import Dispatch

import ArgumentParser

@main
struct HTTPServer: ParsableCommand {
    @Option(name: .shortAndLong, help: "Host to bind to for listening. Defaults to \"localhost\"")
    var host: String = "localhost"
    
    @Option(name: .shortAndLong, help: "Port to listen on. Defaults to 8080")
    var port: Int = 8080
    
    mutating func run() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(HTTPServer._childChannelInitializer(channel:))

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try socketBootstrap.bind(host: host, port: port).wait()
        
        guard let localAddress = channel.localAddress else {
            throw RuntimeError("Unable to bind address for listening")
        }
        
        print("Server started and listening on \"\(host)\" (resolved to \"\(localAddress)\"), port \(port)")
        
        // When the server channel closes, try to shut down gracefully. Doesn't matter if we crash since
        // we're exiting anyway. This won't ever actually happen since we have no exit conditions
        channel.closeFuture.whenComplete { _ in
            try! group.syncShutdownGracefully()
        }
        
        // Start the main queue event loop
        Dispatch.dispatchMain()
    }
    
    private static func _childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler(HTTPRequestHandler())
        }
    }
}
