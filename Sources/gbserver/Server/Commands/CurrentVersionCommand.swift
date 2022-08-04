//
//  File.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import NIOCore
import SQLite

struct CurrentVersionCommand: ServerJSONCommand {
    let name = "currentVersionInfo"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: CurrentVersionCommandPayload.self, data: data, decoder: decoder)
        let future = _run(with: payload, context: context)
        return future
    }
    
    private func _run(with payload: CurrentVersionCommandPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
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
    
    private func _makeResponseData(payload: CurrentVersionCommandPayload, entries: [VersionModel]) throws -> Data {
        let type = payload.reallyRequestedType()
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
        
        init(_ version: VersionModel) {
            build = version.build
            versionName = version.versionName
            type = version.type
        }
    }
}

fileprivate struct CurrentVersionCommandPayload: Decodable {
    let requestedType: VersionType?
    
    func reallyRequestedType() -> VersionType {
        return requestedType ?? .current
    }
}
