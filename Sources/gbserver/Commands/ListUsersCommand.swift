//
//  ListUsersCommand.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import GRDB

struct ListUsersCommand: ServerJSONCommand {
    let name = "listUsers"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: ListUsersXPCRequestPayload.self, data: data, decoder: decoder)
        if payload.displayName != nil && payload.deviceID != nil {
            throw RuntimeError("Fetching on both name and device ID is prohibited")
        }
        
        let queryExpression: SQLSpecificExpressible?
        if let name = payload.displayName {
            queryExpression = (UserModel.displayNameColumn.like(name))
        } else if let deviceID = payload.deviceID {
            queryExpression = (UserModel.deviceIDColumn.like(deviceID))
        } else {
            queryExpression = nil
        }
        
        let dataFuture = context.db.asyncRead(eventLoop: context.eventLoop) { db -> [UserModel] in
            if let queryExpression = queryExpression {
                return try UserModel.filter(queryExpression).fetchAll(db)
            } else {
                return try UserModel.fetchAll(db)
            }
        }.flatMapThrowing { users -> Data in
            let userPayloads = users.map { ListUsersXPCResponsePayload(user: $0) }
            let data = try JSONEncoder().encode(userPayloads)
            return data
        }
        
        return dataFuture
    }
}

fileprivate extension ListUsersXPCResponsePayload {
    init(user: UserModel) {
        self.init(deviceID: user.deviceID, displayName: user.displayName)
    }
}
