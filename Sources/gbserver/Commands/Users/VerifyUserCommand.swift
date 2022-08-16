//
//  VerifyUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/16/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct VerifyUserCommand: ServerJSONCommand {
    let name = "verifyUser"
    
    func run(with arguments: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload: VerifyUserHTTPRequestPayload = try decodeQueryPayload(query: arguments)
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> VerifyUserHTTPResponsePayload in
            let query = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID).limit(1) }
            let users = try UserModel.fetch(dbConnection, queryBuilder: query)
            if users.isEmpty {
                return .userDoesNotExist
            } else {
                return .userExists
            }
        }.flatMapThrowing { responsePayload -> Data in
            return try JSONEncoder().encode(responsePayload)
        }
        
        return responseFuture
    }
}
