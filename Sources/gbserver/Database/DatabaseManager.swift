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
    private let tables: [DatabaseTable.Type]
    
    private static let CurrentSchemaVersion: Int32 = 3
    
    init(_ location: Connection.Location, tables: [DatabaseTable.Type]) throws {
        db = try Connection(location)
        queue = DispatchQueue(label: "DatabaseQueue") // let it be unspecified QoS for now
        self.tables = tables
    }
    
    convenience init(_ path: String, tables: [DatabaseTable.Type]) throws {
        try self.init(.uri(path), tables: tables)
    }
    
    convenience init(tables: [DatabaseTable.Type]) throws {
        try self.init(.inMemory, tables: tables)
    }
    
    func performInitialSetup() throws {
        for table in tables {
            try table.createTableIfNecessary(db)
        }
        
        let userVersion = db.userVersion ?? 0
        if userVersion != 0 { // 0 means never created
            if userVersion < 2 {
                let addColumn = UserModel.table.addColumn(UserModel.debugAuthorized, defaultValue: false)
                try db.run(addColumn)
            }
            if userVersion < 3 {
                let addColumn = UserModel.table.addColumn(UserModel.createRoomAuthorized, defaultValue: false)
                try db.run(addColumn)
            }
        }
        db.userVersion = DatabaseManager.CurrentSchemaVersion
    }
    
    private var enterReadonlyStatement: Statement?
    private func beginReadonly() throws {
        let statement: Statement
        if let stmt = enterReadonlyStatement {
            statement = stmt
        } else {
            statement = try db.prepare("PRAGMA query_only = 1")
        }
        
        try statement.run()
    }
    
    private var exitReadonlyStatement: Statement?
    private func endReadonly() throws {
        let statement: Statement
        if let stmt = exitReadonlyStatement {
            statement = stmt
        } else {
            statement = try db.prepare("PRAGMA query_only = 0")
        }
        
        try statement.run()
    }
    
    func write<T>(_ updates: (Connection) throws -> T) throws -> T {
        var result: T?
        try queue.sync {
            try db.transaction {
                result = try updates(db)
            }
        }
        return result!
    }
    
    func asyncWrite<T>(_ updates: @escaping (Connection) throws -> T, completion: @escaping (Swift.Result<T,Error>) -> Void) {
        let db = self.db
        queue.async {
            do {
                var result: T?
                try db.transaction {
                    result = try updates(db)
                }
                completion(.success(result!))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func read<T>(_ value: (Connection) throws -> T) throws -> T {
        var result: T?
        try queue.sync {
            try throwingFirstError {
                try beginReadonly()
                try db.savepoint {
                    result = try value(db)
                }
            } finally: {
                try endReadonly()
            }
        }
        return result!
    }
    
    func asyncRead<T>(_ value: @escaping (Connection) throws -> T, completion: @escaping (Swift.Result<T,Error>) -> Void) {
        let db = self.db
        queue.async {
            do {
                var result: T?
                try throwingFirstError {
                    try self.beginReadonly()
                    result = try value(db)
                } finally: {
                    try self.endReadonly()
                }
                completion(.success(result!))
            } catch {
                completion(.failure(error))
            }
        }
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
    
    init() {
        query = T.table
    }
}

// MARK: - Table Creation

protocol DatabaseTable {
    // TODO: I bet we could do this way more automatically in swift with property wrappers, etc
    static func createTableIfNecessary(_ db: Connection) throws
}

// MARK: - Inserting

protocol DatabaseInsertable {
    associatedtype InsertRecord
    /// Attempts an insert based on the insertion record. Returns row ID if successful
    @discardableResult
    static func insert(_ db: Connection, record: InsertRecord) throws -> Int64
}

// MARK: - Updating

protocol DatabaseUpdatable: DatabaseFetchable {
    associatedtype UpdateRecord
    /// Attempts to update all objects matching the query based on the update record. Returns the number of updated rows
    static func update(_ db: Connection, query: QueryBuilder<Self>, record: UpdateRecord) throws -> Int
}

// MARK: - Fetching

protocol DatabaseFetchable {
    static func fetch(_ db: Connection, queryBuilder: QueryBuilder<Self>) throws -> [Self]
    static func fetchCount(_ db: Connection, queryBuilder: QueryBuilder<Self>) throws -> Int
    static var table: Table { get }
}

extension DatabaseFetchable {
    static func fetchCount(_ db: Connection, queryBuilder: QueryBuilder<Self>) throws -> Int {
        let query = queryBuilder.query
        return try db.scalar(query.count)
    }
}
