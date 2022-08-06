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
        if payload.name != nil && payload.deviceID != nil {
            throw RuntimeError("Fetching on both name and device ID is prohibited")
        }
        
        let future: EventLoopFuture<[UserModel]>
        if let name = payload.name {
            future = _fetchUsersWithName(name, context: context)
        } else if let deviceID = payload.deviceID {
            future = _fetchUsersWithDeviceID(deviceID, context: context)
        } else {
            future = _fetchAllUsers(context)
        }
        
        let dataFuture = future.flatMapThrowing { users -> Data in
            let userPayloads = users.map { ListUsersXPCResponsePayload(user: $0) }
            let data = try JSONEncoder().encode(userPayloads)
            return data
        }
        
        return dataFuture
    }
    
    private func _fetchAllUsers(_ context: ServerCommandContext) -> EventLoopFuture<[UserModel]> {
        let queryBuilder = QueryBuilder<UserModel>()
        let future = context.db.runFetch(eventLoop: context.eventLoop, queryBuilder: queryBuilder)
        return future
    }
    
    private func _fetchUsersWithName(_ name: String, context: ServerCommandContext) -> EventLoopFuture<[UserModel]> {
        let nameExpression = Expression<String>("name")
        let queryBuilder = QueryBuilder<UserModel> { $0.filter(nameExpression.like(name)) }
        let future = context.db.runFetch(eventLoop: context.eventLoop, queryBuilder: queryBuilder)
        return future
    }
    
    private func _fetchUsersWithDeviceID(_ deviceID: String, context: ServerCommandContext) -> EventLoopFuture<[UserModel]> {
        let queryBuilder = QueryBuilder<UserModel> { $0.filter(UserModel.deviceID.like(deviceID)) }
        let future = context.db.runFetch(eventLoop: context.eventLoop, queryBuilder: queryBuilder)
        return future
    }
}

fileprivate extension ListUsersXPCResponsePayload {
    init(user: UserModel) {
        self.init(deviceID: user.deviceID, name: user.name)
    }
}
