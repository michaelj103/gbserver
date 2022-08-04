//
//  XPCResponseHandler.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import NIOCore

final class XPCResponseHandler: ChannelInboundHandler {
    public typealias InboundIn = XPCResponseMessage
    public typealias OutboundOut = ByteBuffer
    
    private weak var delegate: XPCResponseHandlerDelegate?
    
    init(_ delegate: XPCResponseHandlerDelegate) {
        self.delegate = delegate
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inbound = unwrapInboundIn(data)
        
        switch inbound {
        case .success(let buffer):
            if let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) {
                self.delegate?.handleSuccess(with: data)
            } else {
                // Not sure how this could happen
                self.delegate?.handleError(with: "Failed to read success response")
            }
        case .failure(let message):
            self.delegate?.handleError(with: message)
        }
        
        // It's not strictly necessary to close since we will close when the remote is done
        // May be valuable to allow multiple response packets in the future?
        context.close(promise: nil)
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("XPC communication error: \(error)")
        context.close(promise: nil)
    }
    
}

protocol XPCResponseHandlerDelegate: AnyObject {
    func handleSuccess(with data: Data)
    func handleError(with message: String)
}
