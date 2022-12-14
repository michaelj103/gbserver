//
//  UserModel.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import SQLite
import GBServerPayloads

struct UserModel: DatabaseTable, DatabaseFetchable, DatabaseInsertable, DatabaseUpdatable, DatabaseDeletable {
    let id: Int64
    let deviceID: String
    let displayName: String?
    let debugAuthorized: Bool
    let createRoomAuthorized: Bool
    
    static let table = Table("Users")
    static let id = Expression<Int64>("id")
    static let deviceID = Expression<String>("deviceID")
    static let displayName = Expression<String?>("displayName")
    static let debugAuthorized = Expression<Bool>("debugAuthorized")
    static let createRoomAuthorized = Expression<Bool>("createRoomAuthorized")
    
    static func createTableIfNecessary(_ db: Connection) throws {
        let userCreation = table.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(deviceID, unique: true)
            builder.column(displayName, unique: true)
            builder.column(debugAuthorized, defaultValue: false)
            builder.column(createRoomAuthorized, defaultValue: false)
        }

        try db.run(userCreation)
    }
    
    // MARK: - Fetching
    
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<UserModel>) throws -> [UserModel] {
        let query = queryBuilder.query
        let rowIterator = try db.prepareRowIterator(query)
        let entries: [UserModel] = try rowIterator.map({ element in
            let entry = UserModel(id: element[id], deviceID: element[deviceID], displayName: element[displayName], debugAuthorized: element[debugAuthorized], createRoomAuthorized: element[createRoomAuthorized])
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
    
    @discardableResult
    static func insert(_ db: Connection, record: InsertRecord) throws -> Int64 {
        let insertion = table.insert(deviceID <- record.deviceID, displayName <- record.name, debugAuthorized <- false, createRoomAuthorized <- false)
        let insertedRowID = try db.run(insertion)
        return insertedRowID
    }
    
    // MARK: - Updating
    
    typealias UpdateRecord = UserUpdate
    struct UserUpdate {
        let updatedDisplayName: NullablePropertyWrapper<String>?
        let updatedDebugAuthorizedValue: Bool?
        let updateCreateRoomAuthorizedValue: Bool?
        
        init(displayName: NullablePropertyWrapper<String>?, debugAuthorized: Bool?, createRoomAuthorized: Bool?) {
            self.updatedDisplayName = displayName
            self.updatedDebugAuthorizedValue = debugAuthorized
            self.updateCreateRoomAuthorizedValue = createRoomAuthorized
        }
    }
    
    static func update(_ db: Connection, query: QueryBuilder<UserModel>, record: UserUpdate) throws -> Int {
        var setters = [Setter]()
        if let wrapper = record.updatedDisplayName {
            setters.append(displayName <- wrapper.value)
        }
        if let debugAuth = record.updatedDebugAuthorizedValue {
            setters.append(debugAuthorized <- debugAuth)
        }
        if let createRoomAuth = record.updateCreateRoomAuthorizedValue {
            setters.append(createRoomAuthorized <- createRoomAuth)
        }
        
        if setters.isEmpty {
            return 0
        } else {
            let updateTable = query.query
            let update = updateTable.update(setters)
            let updatedRowCount = try db.run(update)
            return updatedRowCount
        }
    }
}

