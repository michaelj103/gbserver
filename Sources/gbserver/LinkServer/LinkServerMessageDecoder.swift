//
//  LinkServerMessageDecoder.swift
//  
//
//  Created by Michael Brandt on 8/14/22.
//

import NIOCore

// Supported command codes from the client
enum LinkServerCommand: UInt8 {
    case connect = 1
}

// Decoded messages passed along the pipeline for processing
enum LinkServerMessage {
    case connect(String)
}

final class LinkServerMessageDecoder: ByteToMessageDecoder {
    typealias InboundOut = LinkServerMessage
    
    private var decoderState = MessageDecoderState.waitingForCommand
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
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
    
    private func _getCommand(buffer: inout ByteBuffer) throws -> LinkServerCommandDecoder? {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            return nil
        }
        
        guard let command = LinkServerCommand(rawValue: byte) else {
            throw DecodeError.unrecognizedCommand
        }
        
        let decoder: LinkServerCommandDecoder
        switch command {
        case .connect:
            decoder = ConnectCommandDecoder()
        }
        
        return decoder
    }
    
    private enum MessageDecoderState {
        case waitingForCommand
        case waitingForLength(LinkServerCommandDecoder)
        case decodingCommand(Int,LinkServerCommandDecoder)
    }
    
    enum DecodeError: Error {
        case unrecognizedCommand
        case missingBytes
    }
}

fileprivate protocol LinkServerCommandDecoder {
    // Number of bytes specifying length of command. 0 if fixed length
    var lengthFieldSize: Int { get }
    
    // Called once lengthFieldSize bytes are available to read additional length
    func messageLength(buffer: inout ByteBuffer) throws -> Int
    
    // Called once messageLength bytes are available to decode the message, which is sent up the pipeline
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage
}

fileprivate struct ConnectCommandDecoder: LinkServerCommandDecoder {
    // Always 22. 128 bit keys, base64 encoded -> 22 characters
    private static let MessageLength = 22
    
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        return ConnectCommandDecoder.MessageLength
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage {
        guard let key = buffer.readString(length: ConnectCommandDecoder.MessageLength) else {
            throw LinkServerMessageDecoder.DecodeError.missingBytes
        }
        
        return .connect(key)
    }
}
