//
//  AddVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import NIOCore
import GRDB
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
        var versionToInsert = VersionModel(id: nil, build: payload.build, versionName: payload.versionName, type: payload.type)
        let future: EventLoopFuture<Void> = context.db.asyncWrite(eventLoop: context.eventLoop, updates: { db in
            try versionToInsert.insert(db)
        })
        
        let dataFuture: EventLoopFuture<Data> = future.flatMapThrowing { _ in
            let genericResponse = GenericMessageResponse.success(message: "Successfully inserted legacy version \"\(payload.versionName)\"(\(payload.build))")
//            let genericResponse = GenericSuccessResponse(message: "Successfully inserted legacy version \"\(payload.versionName)\"(\(payload.build))")
            let data = try JSONEncoder().encode(genericResponse)
            return data
        }
        
        return dataFuture
    }
    
    private func _addSingletonVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let targetVersionType = payload.type
        var versionToInsert = VersionModel(id: nil, build: payload.build, versionName: payload.versionName, type: targetVersionType)
        let future: EventLoopFuture<Int> = context.db.asyncWrite(eventLoop: context.eventLoop) { db in
            // move existing version of the target type to legacy in the same transaction as the insert
            let updatedCount = try VersionModel
                .filter(VersionModel.typeColumn == targetVersionType.rawValue)
                .updateAll(db, VersionModel.typeColumn.set(to: VersionType.legacy.rawValue))
            try versionToInsert.insert(db)
            return updatedCount
        }
        
        let dataFuture: EventLoopFuture<Data> = future.flatMapThrowing { count in
            let genericResponse = GenericMessageResponse.success(message: "Successfully inserted \(targetVersionType) version \"\(payload.versionName)\"(\(payload.build)). Updated \(count) existing version\(count == 1 ? "" : "s") to legacy")
//            let genericResponse = GenericSuccessResponse(message: "Successfully inserted \(targetVersionType) version \"\(payload.versionName)\"(\(payload.build)). Updated \(count) existing version\(count == 1 ? "" : "s") to legacy")
            let data = try JSONEncoder().encode(genericResponse)
            return data
        }
        
        return dataFuture
    }
}
