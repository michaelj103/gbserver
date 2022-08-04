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
            return _addCurrentVersion(with: payload, context: context)
        case .staging:
            preconditionFailure("Staging Not handled")
//            return _addStagingVersion(with: payload, context: context)
        }
    }
    
    private func _addLegacyVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let insertion = VersionModel.VersionInsertion(build: payload.build, versionName: payload.versionName, type: payload.type)
        
        let encodePromise = context.eventLoop.makePromise(of: Data.self)
        
        context.db.runInsert(eventLoop: context.eventLoop, type: VersionModel.self, insertion: insertion).whenComplete { result in
            switch result {
            case .success(_):
                let genericResponse = GenericSuccessResponse(message: "Successfully inserted legacy version \"\(payload.versionName)\"(\(payload.build))")
                let data: Data
                do {
                    data = try JSONEncoder().encode(genericResponse)
                    encodePromise.succeed(data)
                } catch {
                    encodePromise.fail(error)
                }
            case .failure(let error):
                encodePromise.fail(error)
            }
        }
        return encodePromise.futureResult
    }
    
    private func _addCurrentVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
        let transaction = context.db.createTransaction { manager -> Int in
            // change all existing current versions (should be 1) to legacy
            let queryToUpdate = QueryBuilder<VersionModel> { $0.filter(VersionModel.type == VersionType.current.rawValue) }
            let updateToLegacy = VersionModel.UpdateRecord(.legacy)
            let updatedCount = try manager.updateOnAccessQueue(queryToUpdate, record: updateToLegacy)
            
            // insert the new current version
            let insertion = VersionModel.VersionInsertion(build: payload.build, versionName: payload.versionName, type: payload.type)
            try manager.insertOnAccessQueue(VersionModel.self, insertion: insertion)
            
            return updatedCount
        }
        
        let encodePromise = context.eventLoop.makePromise(of: Data.self)
        context.db.runTransaction(transaction) { result in
            switch result {
            case .success(let count):
                let genericResponse = GenericSuccessResponse(message: "Successfully inserted current version \"\(payload.versionName)\"(\(payload.build)). Updated \(count) existing version\(count == 1 ? "" : "s") to legacy")
                let data: Data
                do {
                    data = try JSONEncoder().encode(genericResponse)
                    encodePromise.succeed(data)
                } catch {
                    encodePromise.fail(error)
                }
            case .failure(let error):
                encodePromise.fail(error)
            }
        }
        
        return encodePromise.futureResult
    }
    
//    private func _addStagingVersion(with payload: AddVersionXPCRequestPayload, context: ServerCommandContext) -> EventLoopFuture<Data> {
//
//    }
}