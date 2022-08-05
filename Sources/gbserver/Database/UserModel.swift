//
//  UserModel.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import SQLite
import GBServerPayloads

struct UserModel: DatabaseTable, DatabaseFetchable, DatabaseInsertable {
    let id: Int64
    let deviceID: String
    let name: String
    
    static let table = Table("Users")
    static let id = Expression<Int64>("id")
    static let deviceID = Expression<String>("deviceID")
    static let name = Expression<String>("name")
    
    static func createIfNecessary(_ db: Connection) throws {
        let userCreation = table.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(deviceID, unique: true)
            builder.column(name)
        }

        try db.run(userCreation)
    }
    
    // MARK: - Fetching
    
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<UserModel>) throws -> [UserModel] {
        let query = queryBuilder.query
        let rowIterator = try db.prepareRowIterator(query)
        let entries: [UserModel] = try rowIterator.map({ element in
            let entry = UserModel(id: element[id], deviceID: element[deviceID], name: element[name])
            return entry
        })
        return entries
    }
    
    // MARK: - Inserting
    
    typealias InsertRecord = UserInsertion
    struct UserInsertion {
        let deviceID: String
        let name: String?
    }
    
    static func insert(_ db: Connection, record: InsertRecord) throws -> Int64 {
        let resolvedName = record.name ?? "Unknown Name"
        let insertion = table.insert(deviceID <- record.deviceID, name <- resolvedName)
        let insertedRowID = try db.run(insertion)
        return insertedRowID
    }
}

