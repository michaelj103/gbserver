//
//  LinkClientMessageDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

// Decoded messages passed along the pipeline for processing
public enum LinkClientMessage {
    case didConnect
}

public final class LinkClientMessageDecoder: ByteToMessageDecoder {
    public typealias InboundOut = LinkClientMessage
    
    public init() {}
    
    private var decoderState = MessageDecoderState.waitingForCommand
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Internal loop is needed to decode command-code-only messages
        // returning .continue won't loop externally if there's no data left in the read buffer
        // except on the last decode (e.g. channel close)
        while true {
            let canContinue = try _internalDecodeStep(context: context, buffer: &buffer)
            if !canContinue {
                break
            }
        }
        
        return .needMoreData
    }
    
    private func _internalDecodeStep(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> Bool {
        switch decoderState {
        case .waitingForCommand:
            if let decoder = try _getCommand(buffer: &buffer) {
                decoderState = .waitingForLength(decoder)
                return true
            } else {
                return false
            }
        case .waitingForLength(let decoder):
            let lengthFieldSize = decoder.lengthFieldSize
            if buffer.readableBytes >= lengthFieldSize {
                let messageLength = try decoder.messageLength(buffer: &buffer)
                decoderState = .decodingCommand(messageLength, decoder)
                return true
            } else {
                return false
            }
        case .decodingCommand(let requiredLength, let decoder):
            if buffer.readableBytes >= requiredLength {
                let message = try decoder.decodeMessage(buffer: &buffer)
                context.fireChannelRead(self.wrapInboundOut(message))
                decoderState = .waitingForCommand
                return true
            } else {
                return false
            }
        }
    }
    
    private func _getCommand(buffer: inout ByteBuffer) throws -> LinkClientCommandDecoder? {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            return nil
        }
        
        guard let command = LinkClientCommand(rawValue: byte) else {
            throw LinkMessageDecodeError.unrecognizedCommand
        }
        
        let decoder: LinkClientCommandDecoder
        switch command {
        case .didConnect:
            decoder = LinkClientDidConnectCommandDecoder()
        }
        
        return decoder
    }
    
    private enum MessageDecoderState {
        case waitingForCommand
        case waitingForLength(LinkClientCommandDecoder)
        case decodingCommand(Int, LinkClientCommandDecoder)
    }
}
