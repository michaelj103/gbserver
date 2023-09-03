//
//  PromoteVersionCommand.swift
//  
//
//  Created by Michael Brandt on 9/2/23.
//

import Foundation
import NIOCore
import SQLite
import GBServerPayloads

struct PromoteVersionCommand: ServerJSONCommand {
    let name = "promoteVersion"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: PromoteVersionXPCRequestPayload.self, data: data, decoder: decoder)
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> UpdateResult in
            // 1. verify that there's exactly one staged version
            let stagedQuery = QueryBuilder<VersionModel> { $0.filter(VersionModel.type == VersionType.staging.rawValue).limit(2) }
            let versions = try VersionModel.fetch(dbConnection, queryBuilder: stagedQuery)
            guard versions.count == 1 else {
                // bail if we have an invalid number of staged
                return versions.count == 0 ? .noStagedVersions : .multipleStagedVersions
            }
            
            // 2. update all current versions to legacy
            let currentQuery = QueryBuilder<VersionModel> { $0.filter(VersionModel.type == VersionType.current.rawValue) }
            let updateToLegacy = VersionModel.UpdateRecord(.legacy)
            let updateToLegacyCount = try VersionModel.update(dbConnection, query: currentQuery, record: updateToLegacy)
            
            // 3. update staging to current and change name if applicable
            let updateToCurrent = VersionModel.UpdateRecord(.current, name: payload.name)
            let updateToCurrentCount = try VersionModel.update(dbConnection, query: stagedQuery, record: updateToCurrent)
            
            return .success(updateToLegacyCount, updateToCurrentCount)
        }.flatMapThrowing { updateResult -> Data in
            let response: GenericMessageResponse
            switch updateResult {
            case .success(let toLegacy, let toCurrent):
                response = GenericMessageResponse.success(message: "Successfully updated \(toCurrent) staged to current. Moved \(toLegacy) current to legacy")
            case .noStagedVersions:
                response = GenericMessageResponse.failure(message: "No staged versions to promote")
            case .multipleStagedVersions:
                response = GenericMessageResponse.failure(message: "Multiple versions are staged")
            }
            
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        
        return responseFuture
    }
    
    private enum UpdateResult {
        case success(Int, Int) // (to legacy count, to current count)
        case noStagedVersions
        case multipleStagedVersions
    }
}
