//
//  LinkServerRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/13/22.
//

import Foundation
import NIOCore
import NIOPosix

class LinkServerRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    private var bytesRead = 0
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = unwrapInboundIn(data)
        let additionalBytes = data.readableBytes - bytesRead
        bytesRead += additionalBytes
        print("Read of \(additionalBytes) byte(s)")
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

