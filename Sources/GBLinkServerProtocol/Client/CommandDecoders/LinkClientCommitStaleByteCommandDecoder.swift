//
//  LinkClientCommitStaleByteCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkClientCommitStaleByteCommandDecoder: LinkClientCommandDecoder {
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        return 0
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkClientMessage {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            throw LinkMessageDecodeError.missingBytes
        }
        
        return .bytePushed(byte)
    }
}
