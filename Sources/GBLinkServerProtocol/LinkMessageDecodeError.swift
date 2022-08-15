//
//  LinkMessageDecodeError.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

public enum LinkMessageDecodeError: Error {
    case unrecognizedCommand
    case missingBytes
}
