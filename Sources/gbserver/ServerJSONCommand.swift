//
//  ServerJSONCommand.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

import Foundation
import NIOCore
import GBServerPayloads

struct ServerCommandContext {
    let eventLoop: EventLoop
    let db: DatabaseManager
}

enum ServerJSONCommandError: Swift.Error {
    case unrecognizedCommand
    case invalidRequestMethod
    case decodeError(underlyingError: Error)
}

class ServerJSONCommandCenter: @unchecked Sendable {
    private var registeredCommands = [String:ServerJSONCommand]()
    private let decoder = JSONDecoder()
    
    func registerCommand(_ command: ServerJSONCommand) {
        let name = command.name
        if let _ = registeredCommands[name] {
            assertionFailure("Multiple registered commands named \(name)")
        }
        registeredCommands[name] = command
    }
    
    func runCommand(_ commandName: String, data: Data, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        guard let command = registeredCommands[commandName] else {
            throw ServerJSONCommandError.unrecognizedCommand
        }
        
        let future = try command.run(with: data, decoder: decoder, context: context)
        return future
    }
    
    func runCommand(_ commandName: String, query: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        guard let command = registeredCommands[commandName] else {
            throw ServerJSONCommandError.unrecognizedCommand
        }
        
        let future = try command.run(with: query, context: context)
        return future
    }
}

protocol ServerJSONCommand {
    var name: String { get }
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data>
    func run(with arguments: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data>
    
    func decodePayload<T: Decodable>(type: T.Type, data: Data, decoder: JSONDecoder) throws -> T
    func decodeQueryPayload<T: QueryDecodable>(query: [URLQueryItem]) throws -> T
}

extension ServerJSONCommand {
    func decodePayload<T: Decodable>(type: T.Type, data: Data, decoder: JSONDecoder) throws -> T {
        let payload: T
        do {
            payload = try decoder.decode(type, from: data)
        } catch {
            throw ServerJSONCommandError.decodeError(underlyingError: error)
        }
        return payload
    }
    
    func decodeQueryPayload<T: QueryDecodable>(query: [URLQueryItem]) throws -> T {
        var dictionary = [String:String]()
        for item in query {
            if let value = item.value {
                dictionary[item.name] = value
            }
        }
        
        let payload: T
        do {
            payload = try T(query: dictionary)
        } catch {
            throw ServerJSONCommandError.decodeError(underlyingError: error)
        }
        return payload
    }
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        context.eventLoop.makeFailedFuture(ServerJSONCommandError.invalidRequestMethod)
    }
    
    func run(with arguments: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        context.eventLoop.makeFailedFuture(ServerJSONCommandError.invalidRequestMethod)
    }
}
