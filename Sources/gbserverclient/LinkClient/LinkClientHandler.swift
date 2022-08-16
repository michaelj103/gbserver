//
//  LinkClientHandler.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOFoundationCompat
import GBLinkServerProtocol

class LinkClientHandler: ChannelInboundHandler {
    public typealias InboundIn = LinkClientMessage
    public typealias OutboundOut = ByteBuffer
    private var sendBytes = 0
    private var receiveBuffer: ByteBuffer = ByteBuffer()
    
    private let connection: LinkClientConnection
    init(_ connection: LinkClientConnection) {
        self.connection = connection
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = unwrapInboundIn(data)
        connection.handleRead(message)
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Channel error: ", error)
        context.close(promise: nil)
    }
}
