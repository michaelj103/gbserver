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
    
    @Option(name: .shortAndLong, help: "Path to a sqlite3 database. Defaults to nil (in memory)")
    var databasePath: String?
        
    mutating func run() throws {
        let database = try _setupDatabase()
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ HTTPServer._childChannelInitializer($0, database: database) })

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try socketBootstrap.bind(host: host, port: port).wait()
        
        guard let localAddress = channel.localAddress else {
            throw RuntimeError("Unable to bind address for listening")
        }
        
        print("Server started and listening on \"\(host)\" port \(port). Resolved to \"\(localAddress)\"")
        
        // When the server channel closes, try to shut down gracefully. Doesn't matter if we crash since
        // we're exiting anyway. This won't ever actually happen since we have no exit conditions
        channel.closeFuture.whenComplete { _ in
            try! group.syncShutdownGracefully()
        }
        
        // Start the main queue event loop
        Dispatch.dispatchMain()
    }
    
    private static func _childChannelInitializer(_ channel: Channel, database: DatabaseManager) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler(HTTPRequestHandler(database))
        }
    }
    
    private func _setupDatabase() throws -> DatabaseManager {
        // Open and set up db
        let database: DatabaseManager
        if let databasePath = databasePath {
            print("Opening database at \(databasePath)")
            database = try DatabaseManager(databasePath)
        } else {
            print("Opening in-memory database")
            database = try DatabaseManager()
        }
        print("Setting up database...", terminator: "")
        do {
            try database.performInitialSetup()
            //TODO: Remove
            try database.insertTestVersion()
        } catch {
            print("Failed")
            throw error
        }
        print("Complete")
        return database
    }
}
