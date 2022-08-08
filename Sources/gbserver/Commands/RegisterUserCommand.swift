//
//  RegisterUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct RegisterUserCommand: ServerJSONCommand {
    let name = "registerUser"
    
    private static let TotalAllowedUsers = 2 // For now. Stop registering users if we exceed this because something is up
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: RegisterUserHTTPRequestPayload.self, data: data, decoder: decoder)
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> Void in
            let insertion = UserModel.InsertRecord(deviceID: payload.deviceID, name: payload.displayName)
            try UserModel.insert(dbConnection, record: insertion)
            
            let allUsersQuery = QueryBuilder<UserModel>()
            let count = try UserModel.fetchCount(dbConnection, queryBuilder: allUsersQuery)
            if count > RegisterUserCommand.TotalAllowedUsers {
                throw RegistrationError.maxCountReached
            }
        }.flatMapThrowing { _ -> Data in
            let response = GenericMessageResponse.success(message: "Successfully registered user")
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        return responseFuture
    }
    
    enum RegistrationError: Error {
        case maxCountReached
    }
}
