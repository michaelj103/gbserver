//
//  JoinRoomCommand.swift
//  
//
//  Created by Michael Brandt on 8/11/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct JoinRoomCommand: ServerJSONCommand {
    let name = "joinRoom"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: JoinRoomHTTPRequestPayload.self, data: data, decoder: decoder)
        if let clientVersion = payload.clientInfo?.clientVersion, clientVersion < 2 {
            throw HTTPRequestHandler.RequestError.commandError("Unsupported client API version")
        }
        let sharedManager = LinkRoomManager.sharedManager
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> Int64 in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                throw HTTPRequestHandler.RequestError.commandError("User not found")
            }
            
            return user.id
        }.flatMapWithEventLoop { userID, eventLoop -> EventLoopFuture<LinkRoomClientInfo> in
            sharedManager.runBlock(eventLoop: eventLoop) { linkManager -> LinkRoomClientInfo in
                try _joinRoom(linkManager, userID: userID, roomCode: payload.roomCode)
            }
        }.flatMapThrowing { clientInfo -> Data in
            return try JSONEncoder().encode(clientInfo)
        }
        
        return responseFuture
    }
    
    private func _joinRoom(_ linkManager: LinkRoomManager, userID: Int64, roomCode: String) throws -> LinkRoomClientInfo {
        // Catch is intentionally not exhaustive. Caught errors should be errors messaged to the user somehow as "bad request"
        // Any other errors should be considered server-side errors and will error-out the whole thing resulting in a 5xx code
        var message: String? = nil
        do {
            let clientInfo = try linkManager.joinRoom(userID, roomCode: roomCode)
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
