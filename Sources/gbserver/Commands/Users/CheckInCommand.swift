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
    
    private static let maxCheckInCount = 100
        
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
            
            let allCheckInsQuery = QueryBuilder<CheckInModel> {
                $0.filter(CheckInModel.userID == user.id).order(CheckInModel.date.asc)
            }
            let allCheckIns = try CheckInModel.fetch(dbConnection, queryBuilder: allCheckInsQuery)
            
            if allCheckIns.count > CheckInCommand.maxCheckInCount {
                let excess = allCheckIns.count - CheckInCommand.maxCheckInCount
                // Could batch, but there should really only ever be 1 excess
                for i in 0..<excess {
                    let checkInID = allCheckIns[i].id
                    let deleteQuery = QueryBuilder<CheckInModel> { $0.filter(CheckInModel.id == checkInID) }
                    try CheckInModel.delete(dbConnection, queryBuilder: deleteQuery)
                }
            }
            
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
