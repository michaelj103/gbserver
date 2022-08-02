//
//  HTTPRequestHandler.swift
//  
//
//  Created by Michael Brandt on 7/31/22.
//

import NIOCore
import NIOHTTP1

import Dispatch

internal final class HTTPRequestHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var buffer: ByteBuffer!
    private var defaultHeaders: HTTPHeaders!
    private let defaultResponse = "Hello There\r\n"
    private let notFoundResponse = "404 Not Found\r\n"
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let requestHeader):
            if !requestHeader.uri.hasPrefix("/api") {
                var responseHead = HTTPResponseHead(version: requestHeader.version, status: .notFound, headers: defaultHeaders)
                responseHead.headers.add(name: "Content-Type", value: "text/plain; charset=UTF-8")
                self.buffer.clear()
                self.buffer.writeString(self.notFoundResponse)
                responseHead.headers.add(name: "Content-Type", value: "text/plain; charset=UTF-8")
                responseHead.headers.add(name: "Content-Length", value: "\(self.buffer!.readableBytes)")
                let response = HTTPServerResponsePart.head(responseHead)
                context.write(self.wrapOutboundOut(response), promise: nil)
            } else {
                var responseHead = HTTPResponseHead(version: requestHeader.version, status: .ok, headers: defaultHeaders)
                self.buffer.clear()
                self.buffer.writeString(self.defaultResponse)
                responseHead.headers.add(name: "Content-Type", value: "text/plain; charset=UTF-8")
                responseHead.headers.add(name: "Content-Length", value: "\(self.buffer!.readableBytes)")
                let response = HTTPServerResponsePart.head(responseHead)
                context.write(self.wrapOutboundOut(response), promise: nil)
            }
        case .body(_):
            print("Read body")
        case .end(_):
            let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
            context.write(self.wrapOutboundOut(content), promise: nil)
            self._completeResponse(context, trailers: nil, promise: nil)
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        print("Channel read complete")
        context.flush()
    }
    
    // Lifecycle call: when the handler is added to the pipeline
    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
        defaultHeaders = HTTPHeaders()
        defaultHeaders.add(name: "Connection", value: "close")
    }
    
    private func _completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        
        let writeAndFlushPromise: EventLoopPromise<Void> = context.eventLoop.makePromise()
        writeAndFlushPromise.futureResult.cascade(to: promise)
        writeAndFlushPromise.futureResult.whenComplete { _ in
            print("Closing")
            context.close(promise: nil)
        }
        
        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: writeAndFlushPromise)
    }
}


extension EventLoopPromise where Value == Void {
    func succeed() {
        self.succeed(())
    }
}
