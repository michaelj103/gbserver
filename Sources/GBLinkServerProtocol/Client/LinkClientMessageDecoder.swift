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
    case pullByte(UInt8)
    case pullByteStale(UInt8)
    case commitStaleByte
    case bytePushed(UInt8)
}

public final class LinkClientMessageDecoder: LinkMessageDecoderBase<LinkClientMessage> {
    
    override func decodeMessage(decoder: LinkCommandDecoder, buffer: inout ByteBuffer) throws -> LinkClientMessage {
        let serverDecoder = decoder as! LinkClientCommandDecoder
        let message = try serverDecoder.decodeMessage(buffer: &buffer)
        return message
    }
    
    override func commandDecoder(for byte: UInt8) throws -> LinkCommandDecoder {
        guard let command = LinkClientCommand(rawValue: byte) else {
            throw LinkMessageDecodeError.unrecognizedCommand
        }
        
        let decoder: LinkClientCommandDecoder
        switch command {
        case .didConnect:
            decoder = LinkClientDidConnectCommandDecoder()
        case .pullByte:
            decoder = LinkClientPullByteCommandDecoder(type: .complete)
        case .pullByteStale:
            decoder = LinkClientPullByteCommandDecoder(type: .stale)
        case .commitStaleByte:
            decoder = LinkClientCommitStaleByteCommandDecoder()
        case .bytePushed:
            decoder = LinkClientBytePushedCommandDecoder()
        }
        
        return decoder
    }
}
