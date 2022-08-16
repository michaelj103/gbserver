//
//  LinkClientPullByteCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkClientPullByteCommandDecoder: LinkClientCommandDecoder {
    enum PullType {
        case complete
        case stale
    }
    
    private let type: PullType
    init(type: PullType) {
        self.type = type
    }
    
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        // single byte in addition to the command code
        return 1
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkClientMessage {
        guard let byte = buffer.readBytes(length: 1)?.first else {
            throw LinkMessageDecodeError.missingBytes
        }
        
        switch type {
        case .complete:
            return .pullByte(byte)
        case .stale:
            return .pullByteStale(byte)
        }
    }
}
