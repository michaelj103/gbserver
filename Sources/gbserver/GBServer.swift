//
//  GBServer.swift
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
struct GBServer: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "gbserver")
    
    @Option(name: .shortAndLong, help: "Host to bind to for listening. Defaults to \"localhost\"")
    var host: String = "localhost"
    
    @Option(name: .shortAndLong, help: "Port to listen on. Defaults to 8080")
    var port: Int = 8080
    
    @Option(name: .shortAndLong, help: "Path to a sqlite3 database. Defaults to nil (in memory)")
    var databasePath: String?
        
    mutating func run() throws {
        let database = try _setupDatabase()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let serverCloseFuture = try _setupHTTPServer(threadGroup: group, database: database)
        let xpcCloseFuture = try _setupXPCServer(threadGroup: group, database: database)
        
        // When the server channels close, try to shut down gracefully. Doesn't matter if we crash since
        // we're exiting anyway. This won't ever actually happen since we currently have no exit conditions
        serverCloseFuture.and(xpcCloseFuture).whenComplete { _ in
            try! group.syncShutdownGracefully()
        }
        
        // Start the main queue event loop
        Dispatch.dispatchMain()
    }
    
    private func _setupHTTPServer(threadGroup: MultiThreadedEventLoopGroup, database: DatabaseManager) throws -> EventLoopFuture<Void> {
        // First, configure the commands that the server responds to
        let commandCenter = ServerJSONCommandCenter()
        commandCenter.registerCommand(CurrentVersionCommand())
        commandCenter.registerCommand(RegisterUserCommand())
        commandCenter.registerCommand(CheckInCommand())
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: threadGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ GBServer._childHTTPChannelInitializer($0, database: database, commandCenter: commandCenter) })

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try socketBootstrap.bind(host: host, port: port).wait()
        
        guard let localAddress = channel.localAddress else {
            throw RuntimeError("Unable to bind address for listening (HTTP)")
        }
        
        print("HTTP server started and listening on \"\(host)\" port \(port). Resolved to \"\(localAddress)\"")
        
        return channel.closeFuture
    }
    
    private static func _childHTTPChannelInitializer(_ channel: Channel, database: DatabaseManager, commandCenter: ServerJSONCommandCenter) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler(HTTPRequestHandler(database, commandCenter: commandCenter))
        }
    }
    
    private func _setupDatabase() throws -> DatabaseManager {
        // Open and set up db
        let tables: [DatabaseTable.Type] = [VersionModel.self,
                                            UserModel.self,
                                            CheckInModel.self,
        ]
        let database: DatabaseManager
        if let databasePath = databasePath {
            print("Opening database at \(databasePath)")
            database = try DatabaseManager(databasePath, tables: tables)
        } else {
            print("Opening in-memory database")
            database = try DatabaseManager(tables: tables)
        }
        print("Setting up database...", terminator: "")
        do {
            try database.performInitialSetup()
        } catch {
            print("Failed")
            throw error
        }
        
        print("Complete")
        return database
    }
    
    private func _setupXPCServer(threadGroup: MultiThreadedEventLoopGroup, database: DatabaseManager) throws -> EventLoopFuture<Void> {
        let path = "/tmp/com.mjb.gbserver"
        // Need to unlink before binding or else you'll get an EADDRINUSE if we weren't shut down cleanly
#if os(macOS)
        Darwin.unlink(path)
#elseif os(Linux)
        Glibc.unlink(path)
#endif
        
        let commandCenter = ServerJSONCommandCenter()
        commandCenter.registerCommand(CurrentVersionCommand())
        commandCenter.registerCommand(AddVersionCommand())
        commandCenter.registerCommand(ListUsersCommand())
        commandCenter.registerCommand(RegisterUserCommand())
        commandCenter.registerCommand(UpdateUserCommand())
        commandCenter.registerCommand(CheckInCommand())
        commandCenter.registerCommand(ListCheckInsCommand())
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: threadGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ GBServer._childXPCChannelInitializer($0, database: database, commandCenter: commandCenter) })

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try socketBootstrap.bind(unixDomainSocketPath: path).wait()
        
        guard let localAddress = channel.localAddress else {
            throw RuntimeError("Unable to bind address for listening (XPC)")
        }
        
        print("XPC server started and listening on \"\(localAddress)")
        
        return channel.closeFuture
    }
    
    private static func _childXPCChannelInitializer(_ channel: Channel, database: DatabaseManager, commandCenter: ServerJSONCommandCenter) -> EventLoopFuture<Void> {
        channel.pipeline.addHandler(ByteToMessageHandler(XPCMessageDecoder())).flatMap { _ in
            channel.pipeline.addHandler(XPCRequestHandler(database, commandCenter: commandCenter))
        }
    }
}
