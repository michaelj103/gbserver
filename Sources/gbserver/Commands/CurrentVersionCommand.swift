//
//  CurrentVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import NIOCore
import GBServerPayloads

struct CurrentVersionCommand: ServerJSONCommand {
    let name = "currentVersionInfo"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: CurrentVersionHTTPRequestPayload.self, data: data, decoder: decoder)
        let future = _run(with: payload, context: context)
        return future
    }
    
    private func _run(with payload: CurrentVersionHTTPRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let type = payload.reallyRequestedType()
        let query = QueryBuilder<VersionModel> { table in
            return table.filter(VersionModel.type == type.rawValue)
        }
        let future = context.db.runFetch(eventLoop: context.eventLoop, queryBuilder: query)
        
        let dataPromise = context.eventLoop.makePromise(of: Data.self)
        future.whenComplete { result in
            switch result {
            case .success(let versionEntries):
                do {
                    let data = try _makeResponseData(payload: payload, entries: versionEntries)
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
    
    private func _makeResponseData(payload: CurrentVersionHTTPRequestPayload, entries: [VersionModel]) throws -> Data {
        let type = payload.reallyRequestedType()
        guard let firstEntry = entries.first else {
            let empty = [String]()
            let data = try JSONEncoder().encode(empty)
            return data
        }
        let response: [CurrentVersionHTTPResponsePayload]
        if type == .legacy {
            response = entries.map { CurrentVersionHTTPResponsePayload($0) }
        } else {
            if entries.count > 1 {
                throw RuntimeError("Multiple versions found for type \(type)")
            }
            response = [CurrentVersionHTTPResponsePayload(firstEntry)]
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
