//
//  LinkClientCommand.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import Foundation

// Supported command codes to client from server
public enum LinkClientCommand: UInt8 {
    // start from 100+ to avoid overlap with server codes
    
    /// Response to a connect attempt if successful
    case didConnect = 101
    
    /// Response to a push byte when the other client has a byte presented
    case pullByte = 102
    
    /// Response to a push byte when the other client has nothing presented
    /// Will be followed by either a pullByte (if the client presents a byte) or a commitStaleByte (if they do anything else)
    case pullByteStale = 103
    
    /// Response to a push byte that only got a stale response to indicate that you will not receive anything better
    /// Allows client to mark the transfer as complete
    case commitStaleByte = 104
    
    /// Response when the client has presented a byte and the other client pushed
    case bytePushed = 105
}
