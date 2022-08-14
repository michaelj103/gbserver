//
//  CurrentVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import NIOCore
import SQLite
import GBServerPayloads

struct CurrentVersionCommand: ServerJSONCommand {
    let name = "currentVersionInfo"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: CurrentVersionHTTPRequestPayload.self, data: data, decoder: decoder)
        let future = _run(with: payload, context: context)
        return future
    }
    
    func run(with arguments: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload: CurrentVersionHTTPRequestPayload = try decodeQueryPayload(query: arguments)
        let future = _run(with: payload, context: context)
        return future
    }
    
    private func _run(with payload: CurrentVersionHTTPRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let type = payload.reallyRequestedType()
        let query = QueryBuilder<VersionModel> { $0.filter(VersionModel.type == type.rawValue) }
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection in
            try VersionModel.fetch(dbConnection, queryBuilder: query)
        }.flatMapThrowing { entries in
            try _makeResponseData(payload: payload, entries: entries)
        }
        
        return responseFuture
    }
    
    private func _makeResponseData(payload: CurrentVersionHTTPRequestPayload, entries: [VersionModel]) throws -> Data {
        let type = payload.reallyRequestedType()
        guard let firstEntry = entries.first else {
            // make a valid empty response if actually empty
            let empty = [String]()
            let data = try JSONEncoder().encode(empty)
            return data
        }
        let response: [CurrentVersionHTTPResponsePayload]
        if type.isSingletonType {
            if entries.count > 1 {
                // Consider this a server-side error. Singleton types having 1 or 0 entries should be enforced server-side
                throw RuntimeError("Multiple versions found for type \(type)")
            }
            response = [CurrentVersionHTTPResponsePayload(firstEntry)]
        } else {
            // multiple is ok. Encode all responses
            response = entries.map { CurrentVersionHTTPResponsePayload($0) }
        }
        
        let data = try JSONEncoder().encode(response)
        return data
    }
}

fileprivate extension CurrentVersionHTTPRequestPayload {
    func reallyRequestedType() -> VersionType {
        return requestedType ?? .current
    }
}

fileprivate extension CurrentVersionHTTPResponsePayload {
    init(_ version: VersionModel) {
        self.init(build: version.build, versionName: version.versionName, type: version.type)
    }
}
