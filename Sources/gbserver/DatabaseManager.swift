//
//  DatabaseManager.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import SQLite
import Dispatch

class DatabaseManager {
    private let db: Connection
    private let queue: DispatchQueue
    private let usersTable = Table("Users")
    private let versionsTable = Table("Versions")
    
    init(_ location: Connection.Location) throws {
        db = try Connection(location)
        queue = DispatchQueue(label: "DatabaseQueue") // let it be unspecified QoS for now
    }
    
    convenience init(_ path: String) throws {
        try self.init(.uri(path))
    }
    
    convenience init() throws {
        try self.init(.inMemory)
    }
    
    func performInitialSetup() throws {
        try _setupUsersTable()
        try _setupVersionsTable()
    }
    
    func fetchOnAccessQueue<T: DatabaseFetchable>(_ queryBuilder: QueryBuilder<T>, completion: @escaping (Swift.Result<[T],Error>) -> ()) {
        let db = self.db
        queue.async {
            let result: Swift.Result<[T],Error>
            do {
                let fetched = try T.fetch(queryBuilder: queryBuilder, db: db)
                result = .success(fetched)
            } catch {
                result = .failure(error)
            }
            completion(result)
        }
    }
        
    private func _setupUsersTable() throws {
        let users = usersTable
        let id = Expression<Int64>("id")
        let deviceID = Expression<String>("deviceID")
        let name = Expression<String>("name")
        
        let userCreation = users.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(deviceID, unique: true)
            builder.column(name)
        }
        
        try db.run(userCreation)
    }
    
    private func _setupVersionsTable() throws {
        let versions = versionsTable
        let id = Expression<Int64>("id")
        let build = Expression<Int64>("build")
        let versionName = Expression<String>("versionName")
        let type = Expression<Int64>("type")
        
        let versionsCreation = versions.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
            builder.column(id, primaryKey: true)
            builder.column(build, unique: true)
            builder.column(versionName, unique: true)
            builder.column(type)
        }
        
        try db.run(versionsCreation)
    }
    
    func insertTestVersion() throws {
        let versions = versionsTable
        let build = Expression<Int64>("build")
        let versionName = Expression<String>("versionName")
        let type = Expression<Int64>("type")
        
        let insert = versions.insert(build <- 3, versionName <- "v0.8.1", type <- VersionType.current.rawValue)
        try db.run(insert)
    }
}

protocol DatabaseFetchable {
    static func fetch(queryBuilder: QueryBuilder<Self>, db: Connection) throws -> [Self]
    static var table: Table { get }
}

enum DatabaseError: Swift.Error {
    case invalidEnumScalarValue
}

struct QueryBuilder<T: DatabaseFetchable> {
    let query: Table
    
    init(_ block: (Table) -> Table) {
        query = block(T.table)
    }
}
