//
//  XPCServerConfiguration.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import NIOCore
import NIOPosix

struct XPCServerConfiguration {
    let socketPath: String
    
    func startXPCServer(threadGroup: MultiThreadedEventLoopGroup, database: DatabaseManager) throws -> EventLoopFuture<Void> {
        let path = socketPath
        // Need to unlink before binding or else you'll get an EADDRINUSE if we weren't shut down cleanly
#if os(macOS)
        Darwin.unlink(path)
#elseif os(Linux)
        Glibc.unlink(path)
#endif
        
        let commandCenter = ServerJSONCommandCenter()
        commandCenter.registerCommand(CurrentVersionCommand())
        commandCenter.registerCommand(AddVersionCommand())
        commandCenter.registerCommand(PromoteVersionCommand())
        commandCenter.registerCommand(ListUsersCommand())
        commandCenter.registerCommand(RegisterUserLegacyCommand())
        commandCenter.registerCommand(UpdateUserCommand())
        commandCenter.registerCommand(CheckInCommand())
        commandCenter.registerCommand(ListCheckInsCommand())
        commandCenter.registerCommand(DeleteUserCommand())
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: threadGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ XPCServerConfiguration._childXPCChannelInitializer($0, database: database, commandCenter: commandCenter) })

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
