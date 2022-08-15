//
//  LinkClientCommand.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import Foundation

// Supported command codes to client from server
public enum LinkClientCommand: UInt8 {
    case didConnect = 2
    
    public func asData() -> Data {
        switch self {
        case .didConnect:
            return Data([self.rawValue])
        }
    }
}
