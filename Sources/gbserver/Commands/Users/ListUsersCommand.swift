//
//  ListUsersCommand.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct ListUsersCommand: ServerJSONCommand {
    let name = "listUsers"
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try decodePayload(type: ListUsersXPCRequestPayload.self, data: data, decoder: decoder)
        if payload.displayName != nil && payload.deviceID != nil {
            throw RuntimeError("Fetching on both name and device ID is prohibited")
        }
        
        let queryBuilder: QueryBuilder<UserModel>
        if let name = payload.displayName {
            queryBuilder = QueryBuilder<UserModel> { $0.filter(UserModel.displayName.like(name)) }
        } else if let deviceID = payload.deviceID {
            queryBuilder = QueryBuilder<UserModel> { $0.filter(UserModel.deviceID.like(deviceID)) }
        } else {
            queryBuilder = QueryBuilder<UserModel>()
        }
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection in
            try UserModel.fetch(dbConnection, queryBuilder: queryBuilder)
        }.flatMapThrowing { users -> Data in
            let userPayloads = users.map { ListUsersXPCResponsePayload(user: $0) }
            let data = try JSONEncoder().encode(userPayloads)
            return data
        }
        
        return responseFuture
    }
}

fileprivate extension ListUsersXPCResponsePayload {
    init(user: UserModel) {
        self.init(deviceID: user.deviceID, displayName: user.displayName, debugAuthorized: user.debugAuthorized, createRoomAuthorized: user.createRoomAuthorized)
    }
}
