//
//  CloseRoomCommand.swift
//  
//
//  Created by Michael Brandt on 8/16/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct CloseRoomCommand: ServerJSONCommand {
    let name = "closeRoom"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: CloseRoomHTTPRequestPayload.self, data: data, decoder: decoder)
        let sharedManager = LinkRoomManager.sharedManager
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> Int64 in
            // part 1: fetch User ID
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                throw HTTPRequestHandler.RequestError.commandError("User not found")
            }
            
            return user.id
        }.flatMapWithEventLoop { userID, eventLoop -> EventLoopFuture<String> in
            sharedManager.runBlock(eventLoop: eventLoop) { linkManager -> String in
                let successMessage = try _closeRoom(linkManager, userID: userID)
                return successMessage
            }
        }.flatMapThrowing { message -> Data in
            let response = GenericMessageResponse.success(message: message)
            return try JSONEncoder().encode(response)
        }
        
        return responseFuture
    }
    
    private func _closeRoom(_ linkManager: LinkRoomManager, userID: Int64) throws -> String {
        // Catch is intentionally not exhaustive. Caught errors should be errors messaged to the user somehow as "bad request"
        // Any other errors should be considered server-side errors and will error-out the whole thing resulting in a 5xx code
        var errorMessage: String? = nil
        do {
            try linkManager.closeRoom(userID)
            return "Successfully closed room"
        } catch LinkRoomError.roomNotFound {
            errorMessage = "User is not in any rooms"
        } catch LinkRoomError.mustBeRoomOwner {
            errorMessage = "Only room owners may close rooms"
        }
        
        // If we get here, we caught an error
        throw HTTPRequestHandler.RequestError.commandError(errorMessage)
    }
}
