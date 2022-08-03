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
    private let tables: [DatabaseTable.Type]
    
    init(_ location: Connection.Location) throws {
        db = try Connection(location)
        queue = DispatchQueue(label: "DatabaseQueue") // let it be unspecified QoS for now
        tables = [VersionModel.self]
    }
    
    convenience init(_ path: String) throws {
        try self.init(.uri(path))
    }
    
    convenience init() throws {
        try self.init(.inMemory)
    }
    
    func performInitialSetup() throws {
        try _setupUsersTable()
        for table in tables {
            try table.createIfNecessary(db)
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

// MARK: - Table Creation

protocol DatabaseTable {
    // TODO: I bet we could do this way more automatically in swift with property wrappers, etc
    static func createIfNecessary(_ db: Connection) throws
}

// MARK: - Inserting

protocol DatabaseInsertable {
    associatedtype InsertRecord
    /// Attempts an insert based on the insertion record. Returns row ID if successful
    static func insert(_ db: Connection, record: InsertRecord) throws -> Int64
}

extension DatabaseManager {
    func insertOnAccessQueue<T: DatabaseInsertable>(_ type: T.Type, insertion: T.InsertRecord, completion: @escaping (Swift.Result<Int64,Error>)-> ()) {
        let db = self.db
        queue.async {
            let result: Swift.Result<Int64,Error>
            do {
                let inserted = try T.insert(db, record: insertion)
                result = .success(inserted)
            } catch {
                result = .failure(error)
            }
            completion(result)
        }
    }
    
    @discardableResult
    func insertOnAccessQueue<T: DatabaseInsertable>(_ type: T.Type, insertion: T.InsertRecord) throws -> Int64 {
        let db = self.db
        var inserted: Int64 = 0
        try queue.sync {
            inserted = try T.insert(db, record: insertion)
        }
        return inserted
    }
}

// MARK: - Updating

protocol DatabaseUpdatable: DatabaseFetchable {
    associatedtype UpdateRecord
    /// Attempts to update all objects matching the query based on the update record. Returns the number of updated rows
    static func update(_ db: Connection, query: QueryBuilder<Self>, record: UpdateRecord) throws -> Int
}

extension DatabaseManager {
    /// Result is the number of updated rows
    func updateOnAccessQueue<T: DatabaseUpdatable>(_ queryBuilder: QueryBuilder<T>, record: T.UpdateRecord, completion: @escaping (Swift.Result<Int,Error>) -> ()) {
        let db = self.db
        queue.async {
            let result: Swift.Result<Int,Error>
            do {
                let updated = try T.update(db, query: queryBuilder, record: record)
                result = .success(updated)
            } catch {
                result = .failure(error)
            }
            completion(result)
        }
    }
}

// MARK: - Fetching

protocol DatabaseFetchable {
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<Self>) throws -> [Self]
    static var table: Table { get }
}

extension DatabaseManager {
    func fetchOnAccessQueue<T: DatabaseFetchable>(_ queryBuilder: QueryBuilder<T>, completion: @escaping (Swift.Result<[T],Error>) -> ()) {
        let db = self.db
        queue.async {
            let result: Swift.Result<[T],Error>
            do {
                let fetched = try T.fetch(db, queryBuilder: queryBuilder)
                result = .success(fetched)
            } catch {
                result = .failure(error)
            }
            completion(result)
        }
    }
}
