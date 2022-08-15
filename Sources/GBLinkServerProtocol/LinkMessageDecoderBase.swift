//
//  LinkMessageDecoderBase.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

public class LinkMessageDecoderBase<MessageType>: ByteToMessageDecoder {
    public typealias InboundOut = MessageType
    
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
            if let decoder = try getCommand(buffer: &buffer) {
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
                let message = try decodeMessage(decoder: decoder, buffer: &buffer)
                context.fireChannelRead(self.wrapInboundOut(message))
                decoderState = .waitingForCommand
                return true
            } else {
                return false
            }
        }
    }
    
    
    private func getCommand(buffer: inout ByteBuffer) throws -> LinkCommandDecoder? {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            return nil
        }
        
        return try commandDecoder(for: byte)
    }
    
    func commandDecoder(for byte: UInt8) throws -> LinkCommandDecoder {
        preconditionFailure("Subclass requirement")
    }
    
    func decodeMessage(decoder: LinkCommandDecoder, buffer: inout ByteBuffer) throws -> MessageType {
        preconditionFailure("Subclass requirement")
    }
    
    private enum MessageDecoderState {
        case waitingForCommand
        case waitingForLength(LinkCommandDecoder)
        case decodingCommand(Int, LinkCommandDecoder)
    }
}

