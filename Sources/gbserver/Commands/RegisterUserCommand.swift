//
//  RegisterUserCommand.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import NIOCore
import GBServerPayloads

struct RegisterUserCommand: ServerJSONCommand {
    let name = "registerUser"
    
    private static let TotalAllowedUsers = 20 // For now. Stop registering users if we exceed this because something is up

    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: RegisterUserHTTPRequestPayload.self, data: data, decoder: decoder)
        
        var userToInsert = UserModel(id: nil, deviceID: payload.deviceID, displayName: payload.displayName)
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { db -> Void in
            let userCount = try UserModel.fetchCount(db)
            if userCount > RegisterUserCommand.TotalAllowedUsers {
                throw RegistrationError.maxCountExceeded
            }
            try userToInsert.insert(db)
        }.flatMapThrowing { _ -> Data in
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
