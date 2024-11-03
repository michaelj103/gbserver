//
//  RegisterUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/16/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct RegisterUserCommand: ServerJSONCommand {
    let name = "registerUser2"
    let registrationAPIKey: String?
    
    private static let TotalAllowedUsers = 20 // For now. Stop registering users if we exceed this because something is up
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: RegisterUserHTTPRequestPayload.self, data: data, decoder: decoder)
        
        guard let apiKey = registrationAPIKey else {
            throw RegistrationError.missingAPIKey
        }
        if apiKey != payload.apiKey {
            throw HTTPRequestHandler.RequestError.commandError("Invalid API Key")
        }
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> String in
            // First check that we haven't hit the count limit
            let allUsersQuery = QueryBuilder<UserModel>()
            let count = try UserModel.fetchCount(dbConnection, queryBuilder: allUsersQuery)
            if count >= RegisterUserCommand.TotalAllowedUsers {
                throw RegistrationError.maxCountReached
            }
            
            // Generate a key and attempt to register a new user
            let deviceID = KeyGenerator.generateKey(size: .bits128)
            let insertion = UserModel.InsertRecord(deviceID: deviceID, name: payload.displayName)
            try UserModel.insert(dbConnection, record: insertion)
            
            return deviceID
        }.flatMapThrowing { deviceID -> Data in
            let response = RegisterUserHTTPResponsePayload(deviceID: deviceID)
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        return responseFuture
    }
    
    enum RegistrationError: Error {
        case maxCountReached
        case missingAPIKey
    }
}
