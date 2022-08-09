//
//  CheckInModel.swift
//  
//
//  Created by Michael Brandt on 8/8/22.
//

import Foundation
import SQLite
import GBServerPayloads

struct CheckInModel: DatabaseTable, DatabaseInsertable, DatabaseFetchable {
    let id: Int64
    let date: Date
    let userID: Int64
    
    static let table = Table("CheckIn")
    static let id = Expression<Int64>("id")
    static let date = Expression<Date>("date")
    static let userID = Expression<Int64>("userID")
    
    static func createTableIfNecessary(_ db: Connection) throws {
        let userCreation = table.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(date)
            builder.column(userID)
            builder.foreignKey(userID, references: UserModel.table, UserModel.id, delete: .cascade)
        }
        
        try db.run(userCreation)
    }
    
    // MARK: - Inserting
    
    typealias InsertRecord = CheckInInsertion
    struct CheckInInsertion {
        let userID: Int64
        let date: Date
    }
    
    @discardableResult
    static func insert(_ db: Connection, record: InsertRecord) throws -> Int64 {
        let insertion = table.insert(date <- record.date, userID <- record.userID)
        let insertedRowID = try db.run(insertion)
        return insertedRowID
    }
    
    // MARK: - Fetching
    
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<CheckInModel>) throws -> [CheckInModel] {
        let query = queryBuilder.query
        let rowIterator = try db.prepareRowIterator(query)
        let entries: [CheckInModel] = try rowIterator.map({ element in
            let entry = CheckInModel(id: element[id], date: element[date], userID: element[userID])
            return entry
        })
        return entries
    }
}
