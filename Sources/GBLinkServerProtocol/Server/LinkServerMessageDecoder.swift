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
    case initialByte(UInt8)
    case pushByte(UInt8)
    case presentByte(UInt8)
}

public final class LinkServerMessageDecoder: LinkMessageDecoderBase<LinkServerMessage> {
    
    override func decodeMessage(decoder: LinkCommandDecoder, buffer: inout ByteBuffer) throws -> LinkServerMessage {
        let serverDecoder = decoder as! LinkServerCommandDecoder
        let message = try serverDecoder.decodeMessage(buffer: &buffer)
        return message
    }
    
    override func commandDecoder(for byte: UInt8) throws -> LinkCommandDecoder {
        guard let command = LinkServerCommand(rawValue: byte) else {
            throw LinkMessageDecodeError.unrecognizedCommand
        }
        
        let decoder: LinkServerCommandDecoder
        switch command {
        case .connect:
            decoder = LinkServerConnectCommandDecoder()
        case .initialByte:
            decoder = LinkServerInitialByteCommandDecoder()
        case .pushByte:
            decoder = LinkServerReceiveByteCommandDecoder(type: .push)
        case .presentByte:
            decoder = LinkServerReceiveByteCommandDecoder(type: .present)
        }
        
        return decoder
    }
}
