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
    func run(context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let query = QueryBuilder<VersionEntry> { table in
            return table.filter(VersionEntry.type == VersionType.current.rawValue)
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
        guard let versionInfo = entries.first else {
            throw RuntimeError("No current version found")
        }
        guard entries.count == 1 else {
            throw RuntimeError("Multiple current versions found")
        }
        
        let data = try JSONEncoder().encode(versionInfo)
        return data
    }
}
