//
//  HTTPRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/12/22.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOFoundationCompat

class HTTPRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart
    
    private let connection: HTTPConnection
    private var channelContext: ChannelHandlerContext?
    
    init(_ connection: HTTPConnection) {
        self.connection = connection
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        self.channelContext = context
        connection.setWriteCallback { [weak self] requestHeader, data in
            self?._write(requestHeader, data: data)
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        self.channelContext = nil
        connection.setWriteCallback(nil)
    }
    
    private func _write(_ header: HTTPRequestHead, data: Data?) {
        channelContext?.eventLoop.scheduleTask(in: .zero, {
            self._eventLoop_write(header, data: data)
        })
    }
    
    private func _eventLoop_write(_ header: HTTPRequestHead, data: Data?) {
        guard let channelContext = channelContext else {
            return
        }

        channelContext.write(self.wrapOutboundOut(.head(header)), promise: nil)
        if let data = data {
            let buffer = ByteBuffer(data: data)
            channelContext.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        channelContext.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    private var header: HTTPResponseHead? = nil
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let clientResponse = self.unwrapInboundIn(data)
        
        switch clientResponse {
        case .head(let responseHead):
            print("Received status: \(responseHead.status)")
            self.header = responseHead
        case .body(let byteBuffer):
            let type = self.header?.headers.first(name: "Content-Type")
            if type?.contains("text/plain") ?? false {
                let string = String(buffer: byteBuffer)
                connection.handleRead(string)
            } else {
                let data = Data(buffer: byteBuffer)
                connection.handleRead(data)
            }
        case .end:
            print("Closing channel.")
            context.close(promise: nil)
        }
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTP Request handler error: ", error)
        context.close(promise: nil)
    }
}
