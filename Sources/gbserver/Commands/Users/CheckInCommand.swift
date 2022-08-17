//
//  CheckInCommand.swift
//  
//
//  Created by Michael Brandt on 8/8/22.
//

import Foundation
import NIOCore
import GBServerPayloads
import SQLite

struct CheckInCommand: ServerJSONCommand {
    let name = "checkIn"
        
    func run(with data: Data, decoder: JSONDecoder, context: ServerCommandContext) throws -> EventLoopFuture<Data> {
        let payload = try self.decodePayload(type: CheckInUserHTTPRequestPayload.self, data: data, decoder: decoder)
        let now = Date()
        
        let responseFuture = context.db.asyncWrite(eventLoop: context.eventLoop) { dbConnection -> CheckInResult in
            let userQuery = QueryBuilder<UserModel>{ $0.filter(UserModel.deviceID == payload.deviceID ).limit(1) }
            guard let user = try UserModel.fetch(dbConnection, queryBuilder: userQuery).first else {
                return CheckInResult.userNotFound
            }
            
            let insertion = CheckInModel.InsertRecord(userID: user.id, date: now, version: payload.version)
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
    
    private enum CheckInResult {
        case userNotFound
        case success(Int64)
    }
}
