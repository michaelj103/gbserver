//
//  XPCRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import NIOCore

final class XPCRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = XPCMessagePart
    public typealias OutboundOut = ByteBuffer
    
    private enum RequestState {
        case waitingForHeader
    }
    
    private var responseBuffer: ByteBuffer!
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inbound = unwrapInboundIn(data)
        switch inbound {
        case .command(let command):
            responseBuffer.writeString("XPC: Got command \(command)\n")
//            print("XPC: Got command \(command)")
        case .body(_):
            responseBuffer.writeString("XPC: Got data\n")
//            print("XPC: Got data")
            let finalPromise: EventLoopPromise<Void> = context.eventLoop.makePromise()
            context.writeAndFlush(wrapOutboundOut(responseBuffer.slice()), promise: finalPromise)
            finalPromise.futureResult.whenComplete { _ in
                context.close(promise: nil)
            }
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    public func handlerAdded(context: ChannelHandlerContext) {
        //TODO: timeout?
        responseBuffer = context.channel.allocator.buffer(capacity: 0)
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("XPC Channel error: ", error)
        context.close(promise: nil)
    }
}

