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
    
    @Option(name: .shortAndLong, help: "Port to listen on for HTTP requests. Defaults to 8080")
    var port: Int = 8080
    
    @Option(name: .shortAndLong, help: "Path to a sqlite3 database. Defaults to nil (in memory)")
    var databasePath: String?
    
    @Option(name: .shortAndLong, help: "API Key that clients must pass to perform restricted operations")
    var key: String?
    
    @Option(help: "Port to listen on for Link Server requests. If not specified, no link server will start")
    var linkPort: Int?
        
    mutating func run() throws {
        let database = try _setupDatabase()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let httpServerConfig = HTTPServerConfiguration(host: host, port: port)
        let serverCloseFuture = try httpServerConfig.startHTTPServer(threadGroup: group, database: database)
        let xpcServerConfig = XPCServerConfiguration(socketPath: "/tmp/com.mjb.gbserver")
        let xpcCloseFuture = try xpcServerConfig.startXPCServer(threadGroup: group, database: database)
        let linkServerConfig = LinkServerConfiguration(host: host, port: linkPort)
        let linkServerCloseFuture = try linkServerConfig.startLinkServer(threadGroup: group)
        
        if let key = key {
            RegisterUserCommand.setAPIKey(key)
        } else {
            print("User registration is disabled (no key)")
        }
        
        // When the server channels close, try to shut down gracefully. Doesn't matter if we crash since
        // we're exiting anyway. This won't ever actually happen since we currently have no exit conditions
        serverCloseFuture.and(xpcCloseFuture).and(linkServerCloseFuture).whenComplete { _ in
            try! group.syncShutdownGracefully()
        }
        
        // Start the main queue event loop
        Dispatch.dispatchMain()
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
}

extension EventLoopFuture {
    
}

