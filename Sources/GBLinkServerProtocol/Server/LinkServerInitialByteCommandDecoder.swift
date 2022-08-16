//
//  LinkServerInitialByteCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkServerInitialByteCommandDecoder: LinkServerCommandDecoder {
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        return 1
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            throw LinkMessageDecodeError.missingBytes
        }
        
        return .initialByte(byte)
    }
}
