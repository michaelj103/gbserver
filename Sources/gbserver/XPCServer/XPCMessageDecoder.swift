//
//  XPCMessageDecoder.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import NIOCore

final class XPCMessageDecoder: ByteToMessageDecoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = XPCMessagePart
    
    private var decoderState = XPCMessageDecoderState.waitingForHeader
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        switch decoderState {
        case .waitingForHeader:
            if let parsedHeader = try XPCMessageHeader(&buffer) {
                decoderState = .waitingForCommand(parsedHeader)
                return .continue
            }
            
        case .waitingForCommand(let header):
            if buffer.readableBytes >= header.commandLength {
                if let commandString = buffer.readString(length: header.commandLength) {
                    decoderState = .waitingForBody(header)
                    context.fireChannelRead(self.wrapInboundOut(.command(commandString)))
                    return .continue
                } else {
                    // we have enough bytes, but the string failed to decode
                    throw XPCMessageDecoderError.commandStringEncoding
                }
            }
            
        case .waitingForBody(let header):
            if buffer.readableBytes >= header.bodyLength {
                context.fireChannelRead(self.wrapInboundOut(.body(buffer.readSlice(length: header.bodyLength)!)))
                decoderState = .done
                return .continue
            }
            
        case .done:
            if buffer.readableBytes > 0 {
                throw XPCMessageDecoderError.messageLengthExceeded
            }
            
        }
        return .needMoreData
    }
}

enum XPCMessageDecoderError : Error {
    case unexpectedEnd
    case invalidPrefix
    case commandStringEncoding
    case messageLengthExceeded
}

enum XPCMessagePart {
    case command(String)
    case body(ByteBuffer)
}

fileprivate enum XPCMessageDecoderState {
    case waitingForHeader
    case waitingForCommand(XPCMessageHeader)
    case waitingForBody(XPCMessageHeader)
    case done
}

fileprivate struct XPCMessageHeader {
    // "MSG" followed by 2 16-bit integers specifying command name length and body length respectively
    private static let HeaderBytes = 7
    
    let commandLength: Int
    let bodyLength: Int
    
    init?(_ buffer: inout ByteBuffer) throws {
        guard buffer.readableBytes >= XPCMessageHeader.HeaderBytes else {
            return nil
        }
        guard let prefixBuffer = buffer.readBytes(length: 3) else {
            throw XPCMessageDecoderError.unexpectedEnd
        }
        guard let prefix = String(bytes: prefixBuffer, encoding: .ascii), prefix == "MSG" else {
            throw XPCMessageDecoderError.invalidPrefix
        }
        guard let commandLength: Int16 = buffer.readInteger() else {
            throw XPCMessageDecoderError.unexpectedEnd
        }
        guard let bodyLength: Int16 = buffer.readInteger() else {
            throw XPCMessageDecoderError.unexpectedEnd
        }
        
        self.commandLength = Int(commandLength)
        self.bodyLength = Int(bodyLength)
    }
}
