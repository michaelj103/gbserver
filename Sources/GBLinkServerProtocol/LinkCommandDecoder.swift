//
//  LinkCommandDecoder.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import NIOCore

protocol LinkCommandDecoder {
    // Number of bytes specifying length of command. 0 if fixed length
    var lengthFieldSize: Int { get }
    
    // Called once lengthFieldSize bytes are available to read additional length
    func messageLength(buffer: inout ByteBuffer) throws -> Int
    
    // Called once messageLength bytes are available to decode the message, which is sent up the pipeline
    func decodeMessage(buffer: inout ByteBuffer) throws -> LinkServerMessage
}
