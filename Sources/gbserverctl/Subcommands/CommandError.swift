//
//  CommandError.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

struct CommandError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}
