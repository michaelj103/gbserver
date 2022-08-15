//
//  LinkServerMessageDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

// Decoded messages passed along the pipeline for processing
public enum LinkServerMessage {
    case connect(String)
}

public final class LinkServerMessageDecoder: ByteToMessageDecoder {
    public typealias InboundOut = LinkServerMessage
    
    public init() {
        
    }
    
    private var decoderState = MessageDecoderState.waitingForCommand
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        switch decoderState {
        case .waitingForCommand:
            if let decoder = try _getCommand(buffer: &buffer) {
                decoderState = .waitingForLength(decoder)
                return .continue
            } else {
                return .needMoreData
            }
        case .waitingForLength(let decoder):
            let lengthFieldSize = decoder.lengthFieldSize
            if buffer.readableBytes >= lengthFieldSize {
                let messageLength = try decoder.messageLength(buffer: &buffer)
                decoderState = .decodingCommand(messageLength, decoder)
                return .continue
            } else {
                return .needMoreData
            }
        case .decodingCommand(let requiredLength, let decoder):
            if buffer.readableBytes >= requiredLength {
                let message = try decoder.decodeMessage(buffer: &buffer)
                context.fireChannelRead(self.wrapInboundOut(message))
                decoderState = .waitingForCommand
                return .continue
            } else {
                return .needMoreData
            }
        }
    }
    
    private func _getCommand(buffer: inout ByteBuffer) throws -> LinkCommandDecoder? {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            return nil
        }
        
        guard let command = LinkServerCommand(rawValue: byte) else {
            throw DecodeError.unrecognizedCommand
        }
        
        let decoder: LinkCommandDecoder
        switch command {
        case .connect:
            decoder = LinkServerConnectCommandDecoder()
        }
        
        return decoder
    }
    
    private enum MessageDecoderState {
        case waitingForCommand
        case waitingForLength(LinkCommandDecoder)
        case decodingCommand(Int, LinkCommandDecoder)
    }
    
    public enum DecodeError: Error {
        case unrecognizedCommand
        case missingBytes
    }
}
