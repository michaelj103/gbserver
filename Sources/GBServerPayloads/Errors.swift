//
//  Errors.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

public struct RequestDecodeError: Error, CustomStringConvertible {
    public var description: String
    init(_ description: String) {
        self.description = description
    }
}
