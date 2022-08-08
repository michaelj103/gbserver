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

func throwingFirstError<T>(execute: () throws -> T, finally: () throws -> Void) throws -> T {
    var result: T?
    var firstError: Error?
    do {
        result = try execute()
    } catch {
        firstError = error
    }
    do {
        try finally()
    } catch {
        if firstError == nil {
            firstError = error
        }
    }
    if let firstError = firstError {
        throw firstError
    }
    return result!
}
