//
//  LinkServerCommand.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

// Supported command codes to server from client
public enum LinkServerCommand: UInt8 {
    
    /// Signal from the client to attempt to connect to a room
    case connect = 1
    
    /// Signal from the client to set the initial byte. Should immediately follow successful connection
    case initialByte = 2
    
    /// Signal from the client to push a byte for transfer. A response is expected
    case pushByte = 3
    
    /// Signal from the client that a new byte is available for pull from the other client
    case presentByte = 4
}
