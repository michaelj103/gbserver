//
//  JSONCommandCenter.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

import Foundation

class JSONCommandCenter {
    private var commandTypes = [String : JSONCommand.Type]()
    let decoder = JSONDecoder()
    
    func registerCommand(name: String, type: JSONCommand.Type) {
        commandTypes[name] = type
    }
    
    func decodeCommand(_ name: String, data: Data) throws -> JSONCommand {
        guard let type = commandTypes[name] else {
            throw JSONCommandError.unrecognizedCommand
        }
        do {
            let decoded = try type.decode(decoder, data: data)
            return decoded
        } catch {
            throw JSONCommandError.decodeError(underlyingError: error)
        }
    }
}

enum JSONCommandError: Swift.Error {
    case unrecognizedCommand
    case decodeError(underlyingError: Error)
}

protocol JSONCommand: Decodable {
    static func decode(_ decoder: JSONDecoder, data: Data) throws -> Self
}

extension JSONCommand {
    static func decode(_ decoder: JSONDecoder, data: Data) throws -> Self {
        let decoded = try decoder.decode(Self.self, from: data)
        return decoded
    }
}
