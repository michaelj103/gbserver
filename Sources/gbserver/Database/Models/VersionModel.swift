//
//  VersionModel.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import SQLite
import GBServerPayloads

struct VersionModel: DatabaseTable, DatabaseInsertable, DatabaseFetchable, DatabaseUpdatable {
    let id: Int64
    let build: Int64
    let versionName: String
    let type: VersionType
    
    static let table = Table("Versions")
    static let id = Expression<Int64>("id")
    static let build = Expression<Int64>("build")
    static let versionName = Expression<String>("versionName")
    static let type = Expression<Int64>("type")
    
    // MARK: - Creating
    
    static func createTableIfNecessary(_ db: Connection) throws {
        let versionsCreation = table.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(build, unique: true)
            builder.column(versionName, unique: true)
            builder.column(type)
        }
        
        try db.run(versionsCreation)
    }
    
    // MARK: - Fetching
    
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<VersionModel>) throws -> [VersionModel] {
        let query = queryBuilder.query
        let rowIterator = try db.prepareRowIterator(query)
        let entries: [VersionModel] = try rowIterator.map({ element in
            let entry = VersionModel(id: element[id], build: element[build], versionName: element[versionName], type: try _type(element[type]))
            return entry
        })
        return entries
    }
    
    private static func _type(_ rawValue: Int64) throws -> VersionType {
        guard let resolvedType = VersionType(rawValue: rawValue) else {
            throw DatabaseError.invalidEnumScalarValue
        }
        return resolvedType
    }
    
    // MARK: - Inserting
    
    typealias InsertRecord = VersionInsertion
    struct VersionInsertion {
        let build: Int64
        let versionName: String
        let type: VersionType
    }
    
    @discardableResult
    static func insert(_ db: Connection, record: VersionInsertion) throws -> Int64 {
        let insertion = table.insert(build <- record.build, versionName <- record.versionName, type <- record.type.rawValue)
        let insertedRowID = try db.run(insertion)
        return insertedRowID
    }
    
    // MARK: - Updating
    typealias UpdateRecord = VersionUpdate
    struct VersionUpdate {
        let type: VersionType
        init(_ t: VersionType) {
            type = t
        }
    }
    
    static func update(_ db: Connection, query: QueryBuilder<VersionModel>, record: VersionUpdate) throws -> Int {
        let updateTable = query.query
        let update = updateTable.update(type <- record.type.rawValue)
        let updatedRows = try db.run(update)
        return updatedRows
    }
}
