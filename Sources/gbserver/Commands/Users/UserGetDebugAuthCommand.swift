//
//  UserGetDebugAuthCommand.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct UserGetDebugAuthCommand: ServerJSONCommand {
    let name = "debugAuth"
    
    func run(with arguments: [URLQueryItem], context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload: UserGetDebugAuthHTTPRequestPayload = try decodeQueryPayload(query: arguments)
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> QueryResult in
            let query = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID) }
            let users = try UserModel.fetch(dbConnection, queryBuilder: query)
            guard let user = users.first else {
                return .failure("No user with ID")
            }
            guard users.count == 1 else {
                return .failure("Multiple users found with ID")
            }
            
            return .success(user.debugAuthorized)
        }.flatMapThrowing { result -> Data in
            let response: UserGetDebugAuthHTTPResponsePayload
            switch result {
            case .success(let authorized):
                response = UserGetDebugAuthHTTPResponsePayload(authorized)
            case .failure(let message):
                print("Failed to get user authorization status - \(message)")
                response = UserGetDebugAuthHTTPResponsePayload(false)
            }
            
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        return responseFuture
    }
    
    private enum QueryResult {
        case success(Bool)
        case failure(String)
    }
}
