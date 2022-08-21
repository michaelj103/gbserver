//
//  LinkServerConnectCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkServerConnectCommandDecoder: LinkServerCommandDecoder {
    // Always 22. 128 bit keys, base64 encoded -> 22 characters
    private static let MessageLength = 22
    
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        return LinkServerConnectCommandDecoder.MessageLength
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage {
        guard let key = buffer.readString(length: LinkServerConnectCommandDecoder.MessageLength) else {
            throw LinkMessageDecodeError.missingBytes
        }
        
        return .connect(key)
    }
}
