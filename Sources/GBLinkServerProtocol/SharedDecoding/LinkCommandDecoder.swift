//
//  LinkCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

// It's crap that these need to be split up but a version with a dynamic message type is tough to pull off
// with Swift associated types. Would love to figure that out eventually

protocol LinkCommandDecoder {
    // Number of bytes specifying length of command. 0 if fixed length
    var lengthFieldSize: Int { get }
    
    // Called once lengthFieldSize bytes are available to read additional length
    func messageLength(buffer: inout ByteBuffer) throws -> Int
}

protocol LinkServerCommandDecoder: LinkCommandDecoder {
    // Called once messageLength bytes are available to decode the message, which is sent up the pipeline
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage
}

protocol LinkClientCommandDecoder: LinkCommandDecoder {
    // Called once messageLength bytes are available to decode the message, which is sent up the pipeline
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkClientMessage
}
