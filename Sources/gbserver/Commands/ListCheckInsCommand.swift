//
//  ListCheckInsCommand.swift
//  
//
//  Created by Michael Brandt on 8/8/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct ListCheckInsCommand: ServerJSONCommand {
    let name = "listCheckIns"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: ListCheckInsXPCRequestPayload.self, data: data, decoder: decoder)
        
        let responseFuture = context.db.asyncRead(eventLoop: context.eventLoop) { dbConnection -> ListCheckInResult in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                return ListCheckInResult.userNotFound
            }
            
            let checkInsQuery = QueryBuilder<CheckInModel> {
                $0.filter(CheckInModel.userID == user.id).limit(payload.maxCount).order(CheckInModel.date.desc)
            }
            let checkIns = try CheckInModel.fetch(dbConnection, queryBuilder: checkInsQuery)
            return .success(checkIns)
        }.flatMapThrowing { result -> Data in
            let data: Data
            switch result {
            case .userNotFound:
                let response = GenericMessageResponse.failure(message: "User Not Found")
                data = try JSONEncoder().encode(response)
            case .success(let checkIns):
                let dates = checkIns.map { $0.date }
                let response = ListCheckInsXPCResponsePayload(deviceID: payload.deviceID, checkIns: dates)
                data = try JSONEncoder().encode(response)
            }
            return data
        }
        
        return responseFuture
    }
    
    private enum ListCheckInResult {
        case userNotFound
        case success([CheckInModel])
    }
}
