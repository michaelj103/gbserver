//
//  GetRoomInfoCommand.swift
//  
//
//  Created by Michael Brandt on 8/16/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct GetRoomInfoCommand: ServerJSONCommand {
    let name = "getRoomInfo"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: GetRoomInfoHTTPRequestPayload.self, data: data, decoder: decoder)
        let sharedManager = LinkRoomManager.sharedManager
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> Int64 in
            // part 1: fetch User ID
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                throw HTTPRequestHandler.RequestError.commandError("User not found")
            }
            
            return user.id
        }.flatMapWithEventLoop { userID, eventLoop -> EventLoopFuture<PossibleLinkRoomClientInfo> in
            // part 2: get room info, if any and wrap in a response payload
            sharedManager.runBlock(eventLoop: eventLoop) { linkManager -> PossibleLinkRoomClientInfo in
                if let clientInfo = try linkManager.getCurrentRoom(userID) {
                    return .isInRoom(clientInfo)
                } else {
                    return .isNotInRoom
                }
            }
        }.flatMapThrowing { possibleClientInfo -> Data in
            // part 3: encode the payload for a response
            try JSONEncoder().encode(possibleClientInfo)
        }
        
        return responseFuture
    }
}
