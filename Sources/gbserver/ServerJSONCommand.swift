//
//  ServerJSONCommand.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

import NIOCore
import Foundation
import SQLite

struct ServerCommandContext {
    let eventLoop: EventLoop
    let db: DatabaseManager
}

protocol ServerJSONCommand: JSONCommand {
    func run(context: ServerCommandContext) throws -> EventLoopFuture<Data>
}

struct CurrentVersionCommand: ServerJSONCommand {
    let requestedType: VersionType?
    
    private func _requestedType() -> VersionType {
        return requestedType ?? .current
    }
    
    func run(context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let type = _requestedType()
        let query = QueryBuilder<VersionEntry> { table in
            return table.filter(VersionEntry.type == type.rawValue)
        }
        let future = context.db.runFetch(eventLoop: context.eventLoop, queryBuilder: query)
        
        let dataPromise = context.eventLoop.makePromise(of: Data.self)
        future.whenComplete { result in
            switch result {
            case .success(let versionEntries):
                do {
                    let data = try _makeResponseData(versionEntries)
                    dataPromise.succeed(data)
                } catch {
                    dataPromise.fail(error)
                }
            case .failure(let error):
                dataPromise.fail(error)
            }
        }
        return dataPromise.futureResult
    }
    
    func _makeResponseData(_ entries: [VersionEntry]) throws -> Data {
        let type = _requestedType()
        guard let versionInfo = entries.first else {
            throw RuntimeError("No version found for type \(type)")
        }
        guard entries.count == 1 || type == .legacy else {
            // It's a server configuration error to have multiple staging or current versions
            throw RuntimeError("Multiple versions found for type \(type)")
        }
        
        let response = CurrentVersionResponse(versionInfo)
        let data = try JSONEncoder().encode(response)
        return data
    }
    
    private struct CurrentVersionResponse : Encodable {
        let build: Int64
        let versionName: String
        let type: VersionType
        
        init(_ version: VersionEntry) {
            build = version.build
            versionName = version.versionName
            type = version.type
        }
    }
}
