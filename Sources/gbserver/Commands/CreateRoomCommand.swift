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
        
        context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> Int64 in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                throw HTTPRequestHandler.RequestError.commandError("User not found")
            }
            
            return user.id
        }.flatMapWithEventLoop { userID, eventLoop in
            sharedManager.runBlock(eventLoop: eventLoop) { linkManager in
                let room = linkManager.createRoom(userID)
                room.roomCode
            }
        }
        
        sharedManager.runBlock(eventLoop: context.eventLoop) { linkManager in
            linkManager.createRoom(<#T##userID: Int64##Int64#>)
        }
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> CheckInResult in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                return CheckInResult.userNotFound
            }
            
            let insertion = CheckInModel.InsertRecord(userID: user.id, date: now)
            let checkInRowID = try CheckInModel.insert(dbConnection, record: insertion)
            return .success(checkInRowID)
        }.flatMapThrowing { checkInResult -> Data in
            let response: GenericMessageResponse
            switch checkInResult {
            case .userNotFound:
                response = .failure(message: "User Not Found")
            case .success(_):
                response = .success(message: "CheckIn Successful")
            }
            let data = try JSONEncoder().encode(response)
            return data
        }
        
        return responseFuture
    }
    
    private enum GetUserResult {
        case userNotFound
        case success(Int64)
    }
    
    private enum CreateRoomResult {
        
    }
}
