//
//  Types.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    
    init(_ description: String) {
        self.description = description
    }
}
