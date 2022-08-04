//
//  XPCResponseDecoder.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import NIOCore

enum XPCResponseMessage {
    case success(ByteBuffer)
    case failure(String)
}

enum XPCResponseError : Error {
    case badStartByte
    case failureMessageDecode
    case tooMuchData
}

fileprivate enum XPCResponseDecoderState {
    case initial
    case waitingForLength(responseSuccess: Bool)
    case waitingForData(responseSuccess: Bool, length: Int)
    case done
}

final class XPCResponseDecoder: ByteToMessageDecoder {
    typealias InboundOut = XPCResponseMessage
    
    private var decoderState = XPCResponseDecoderState.initial
    
    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        switch decoderState {
        case .initial:
            if let initialByte: UInt8 = buffer.readInteger() {
                if initialByte == 1 {
                    decoderState = .waitingForLength(responseSuccess: true)
                    return .continue
                } else if initialByte == 0 {
                    decoderState = .waitingForLength(responseSuccess: false)
                    return .continue
                } else {
                    throw XPCResponseError.badStartByte
                }
            }
            
        case .waitingForLength(responseSuccess: let responseSuccess):
            if let lengthByte: Int32 = buffer.readInteger() {
                decoderState = .waitingForData(responseSuccess: responseSuccess, length: Int(lengthByte))
                return .continue
            }
            
        case .waitingForData(responseSuccess: let responseSuccess, length: let length):
            if buffer.readableBytes >= length {
                if responseSuccess {
                    let data = buffer.readSlice(length: length)!
                    context.fireChannelRead(wrapInboundOut(.success(data)))
                } else {
                    if let string = buffer.readString(length: length, encoding: .utf8) {
                        context.fireChannelRead(wrapInboundOut(.failure(string)))
                    } else {
                        throw XPCResponseError.failureMessageDecode
                    }
                }
                decoderState = .done
                return .continue
            }
        
        case .done:
            if buffer.readableBytes > 0 {
                throw XPCResponseError.tooMuchData
            }
            
        }
        
        return .needMoreData
    }
}
