//
//  HTTPServerConfiguration.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import NIOCore
import NIOHTTP1
import NIOPosix

struct HTTPServerConfiguration {
    let host: String
    let port: Int
    
    func startHTTPServer(threadGroup: MultiThreadedEventLoopGroup, database: DatabaseManager) throws -> EventLoopFuture<Void> {
        // First, configure the commands that the server responds to
        let commandCenter = ServerJSONCommandCenter()
        commandCenter.registerCommand(CurrentVersionCommand())
        commandCenter.registerCommand(RegisterUserCommand())
        commandCenter.registerCommand(CheckInCommand())
        commandCenter.registerCommand(UserGetDebugAuthCommand())
        commandCenter.registerCommand(CreateRoomCommand())
        commandCenter.registerCommand(JoinRoomCommand())
        commandCenter.registerCommand(CloseRoomCommand())
        commandCenter.registerCommand(GetRoomInfoCommand())
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: threadGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ HTTPServerConfiguration._childHTTPChannelInitializer($0, database: database, commandCenter: commandCenter) })

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
}
