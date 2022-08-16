//
//  DeleteUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/16/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct DeleteUserCommand: ServerJSONCommand {
    let name = "deleteUser"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: DeleteUserXPCRequestPayload.self, data: data, decoder: decoder)
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> Int in
            let fetchQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: fetchQuery).first else {
                throw DeleteUserError.userNotFound
            }
            
            let deleteQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.id == user.id).limit(1) }
            let deletedCount = try UserModel.delete(dbConnection, queryBuilder: deleteQuery)
            return deletedCount
        }.flatMapThrowing { deleteCount -> Data in
            let payload = GenericMessageResponse.success(message: "Deleted \(deleteCount) user\(deleteCount == 1 ? "" : "s")")
            return try JSONEncoder().encode(payload)
        }
        
        return responseFuture
    }
    
    enum DeleteUserError: Error {
        case userNotFound
    }
}
