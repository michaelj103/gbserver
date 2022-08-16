//
//  LinkClientBytePushedCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

struct LinkClientBytePushedCommandDecoder: LinkClientCommandDecoder {
    let lengthFieldSize: Int = 0
    func messageLength(buffer: inout ByteBuffer) -> Int {
        return 1
    }
    
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkClientMessage {
        return .didConnect
    }
}
