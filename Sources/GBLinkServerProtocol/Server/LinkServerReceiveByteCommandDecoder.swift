//
//  LinkServerReceiveByteCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkServerReceiveByteCommandDecoder: LinkServerCommandDecoder {
    enum ReceiveType {
        case push
        case present
    }
    
    private let type: ReceiveType
    init(type: ReceiveType) {
        self.type = type
    }
    
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        // single byte in addition to the command code
        return 1
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            throw LinkMessageDecodeError.missingBytes
        }
        
        switch type {
        case .push:
            return .pushByte(byte)
        case .present:
            return .presentByte(byte)
        }
    }
}
