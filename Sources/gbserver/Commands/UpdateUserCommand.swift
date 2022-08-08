//
//  UpdateUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/8/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct UpdateUserCommand: ServerJSONCommand {
    let name = "updateUser"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: UpdateUserXPCRequestPayload.self, data: data, decoder: decoder)
        // Note, if there are other properties that can be updated in the future, we can't just always set the displayName like this
        let newDisplayName: String? = payload.updatedName?.value
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> UpdateResult in
            let userFetch = QueryBuilder<UserModel> { $0.filter(UserModel.deviceID == payload.deviceID) }
            let users = try UserModel.fetch(dbConnection, queryBuilder: userFetch)
            guard let user = users.first else {
                return .noMatchingUsers
            }
            
            let update = UserModel.UpdateRecord(displayName: newDisplayName)
            let updatedRowCount = try UserModel.update(dbConnection, query: userFetch, record: update)
            if updatedRowCount == 0 {
                return .noMatchingUsers
            } else if updatedRowCount > 1 {
                // This shouldn't be possible, consider it a server error
                throw RuntimeError("UpdateUser: Multiple matching users for deviceID \(payload.deviceID)")
            }
            return .success(user.displayName)
        }.flatMapThrowing { updateResult -> Data in
            let genericResponse: GenericMessageResponse
            switch updateResult {
            case .success(let oldName):
                genericResponse = GenericMessageResponse.success(message: "Successfully updated from \(oldName ?? "<Null>") to \(newDisplayName ?? "<Null>")")
            case .noMatchingUsers:
                genericResponse = GenericMessageResponse.failure(message: "No users found that match the given deviceID")
            }
            let data = try JSONEncoder().encode(genericResponse)
            return data
        }
        
        return responseFuture
    }
    
    private enum UpdateResult {
        case success(String?)
        case noMatchingUsers
    }
}
