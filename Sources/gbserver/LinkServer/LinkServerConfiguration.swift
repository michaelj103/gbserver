//
//  LinkServerConfiguration.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix

struct LinkServerConfiguration {
    let host: String
    let port: Int?
    
    func startLinkServer(threadGroup: MultiThreadedEventLoopGroup) throws -> EventLoopFuture<Void> {
        guard let port = port else {
            print("No link server port specified. Will not listen for link room connections")
            // return a close future that is already succeeded
            let future = threadGroup.next().makeSucceededFuture(())
            return future
        }
        
        
        // Set up server with configuration options
        let socketBootstrap = ServerBootstrap(group: threadGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ LinkServerConfiguration._childChannelInitializer($0) })

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        let channel = try socketBootstrap.bind(host: host, port: port).wait()
        
        guard let localAddress = channel.localAddress else {
            throw RuntimeError("Unable to bind address for listening (LinkServer)")
        }
        
        LinkRoomManager.sharedManager.setServerPort(port)
        print("Link server started and listening on \"\(localAddress)")
        
        return channel.closeFuture
    }
    
    private static func _childChannelInitializer(_ channel: Channel) -> EventLoopFuture<Void> {
        channel.pipeline.addHandler(LinkServerRequestHandler())
//        channel.pipeline.addHandler(ByteToMessageHandler(XPCMessageDecoder())).flatMap { _ in
//            channel.pipeline.addHandler(XPCRequestHandler(database, commandCenter: commandCenter))
//        }
    }
}
