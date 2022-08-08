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
    
    private static let TotalAllowedUsers = 20 // For now. Stop registering users if we exceed this because something is up
    
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: RegisterUserHTTPRequestPayload.self, data: data, decoder: decoder)
        
        let allUsers = try context.db.fetchOnAccessQueue(QueryBuilder<UserModel>())
        if allUsers.count >= RegisterUserCommand.TotalAllowedUsers {
            throw RegistrationError.maxCountExceeded
        }
        
        let insertion = UserModel.InsertRecord(deviceID: payload.deviceID, name: payload.displayName)
        let insertionFuture = context.db.runInsert(eventLoop: context.eventLoop, type: UserModel.self, insertion: insertion)
        
        let responseFuture = insertionFuture.flatMapThrowing { _ -> Data in
            let response = GenericMessageResponse.success(message: "Successfully registered user")
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        return responseFuture
    }
    
    enum RegistrationError: Error {
        case maxCountExceeded
    }
}
