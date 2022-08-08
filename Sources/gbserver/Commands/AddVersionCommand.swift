//
//  AddVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import NIOCore
import SQLite
import GBServerPayloads

struct AddVersionCommand: ServerJSONCommand {
    let name = "addVersionInfo"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: AddVersionXPCRequestPayload.self, data: data, decoder: decoder)
        let future = _run(with: payload, context: context)
        return future
    }
    
    private func _run(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        switch payload.type {
        case .legacy:
            return _addLegacyVersion(with: payload, context: context)
        case .current:
            return _addSingletonVersion(with: payload, context: context)
        case .staging:
            return _addSingletonVersion(with: payload, context: context)
        }
    }
    
    private func _addLegacyVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let insertion = VersionModel.VersionInsertion(build: payload.build, versionName: payload.versionName, type: payload.type)
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection in
            try VersionModel.insert(dbConnection, record: insertion)
        }.flatMapThrowing { _ -> Data in
            let genericResponse = GenericMessageResponse.success(message: "Successfully inserted legacy version \"\(payload.versionName)\"(\(payload.build))")
            let data = try JSONEncoder().encode(genericResponse)
            return data
        }
        
        return responseFuture
    }
    
    private func _addSingletonVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let targetVersionType = payload.type
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> Int in
            // change all existing targetVersionType versions (should be 1) to legacy in the same transaction as the insert
            let queryToUpdate = QueryBuilder<VersionModel> { $0.filter(VersionModel.type == targetVersionType.rawValue) }
            let updateToLegacy = VersionModel.UpdateRecord(.legacy)
            let updatedCount = try VersionModel.update(dbConnection, query: queryToUpdate, record: updateToLegacy)
            
            // insert the new targetVersionType version
            let insertion = VersionModel.VersionInsertion(build: payload.build, versionName: payload.versionName, type: targetVersionType)
            try VersionModel.insert(dbConnection, record: insertion)
            
            return updatedCount
        }.flatMapThrowing { count -> Data in
            let genericResponse = GenericMessageResponse.success(message: "Successfully inserted \(targetVersionType) version \"\(payload.versionName)\"(\(payload.build)). Updated \(count) existing version\(count == 1 ? "" : "s") to legacy")
            let data = try JSONEncoder().encode(genericResponse)
            return data
        }
        
        return responseFuture
    }
}
