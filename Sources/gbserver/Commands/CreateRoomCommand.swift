//
//  CreateRoomCommand.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct CreateRoomCommand: ServerJSONCommand {
    let name = "createRoom"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: CreateRoomHTTPRequestPayload.self, data: data, decoder: decoder)
        let sharedManager = LinkRoomManager.sharedManager
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> Int64 in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                throw HTTPRequestHandler.RequestError.commandError("User not found")
            }
            
            return user.id
        }.flatMapWithEventLoop { userID, eventLoop -> EventLoopFuture<LinkRoomClientInfo> in
            sharedManager.runBlock(eventLoop: eventLoop) { linkManager -> LinkRoomClientInfo in
                try _createRoom(linkManager, userID: userID)
            }
        }.flatMapThrowing { clientInfo -> Data in
            return try JSONEncoder().encode(clientInfo)
        }
        
        return responseFuture
    }
    
    private func _createRoom(_ linkManager: LinkRoomManager, userID: Int64) throws -> LinkRoomClientInfo {
        // Catch is intentionally not exhaustive. Caught errors should be errors messaged to the user somehow as "bad request"
        // Any other errors should be considered server-side errors and will error-out the whole thing resulting in a 5xx code
        var message: String? = nil
        do {
            let clientInfo = try linkManager.createRoom(userID)
            return clientInfo
        } catch LinkRoomError.userAlreadyInRoom {
            message = "User already in a room"
        } catch LinkRoomError.roomNotFound {
            message = "Room not found"
        } catch LinkRoomError.roomExpired {
            message = "Room expired"
        } catch LinkRoomError.incorrectParticipant {
            message = "Room is full"
        }
        
        // If we get here, we caught an error
        throw HTTPRequestHandler.RequestError.commandError(message)
    }
}
