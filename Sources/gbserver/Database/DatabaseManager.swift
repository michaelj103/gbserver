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
    private let transactionQueue: DispatchQueue
    private let tables: [DatabaseTable.Type]
    
    init(_ location: Connection.Location, tables: [DatabaseTable.Type]) throws {
        db = try Connection(location)
        queue = DispatchQueue(label: "DatabaseQueue") // let it be unspecified QoS for now
        transactionQueue = DispatchQueue(label: "TransactionQueue")
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
    }
    
    private var isInTransaction = false
    private func startTransaction() {
        transactionQueue.sync {
            precondition(!isInTransaction, "Nested transactions not supported")
            isInTransaction = true
        }
    }
    
    private func endTransaction() {
        transactionQueue.sync {
            precondition(isInTransaction, "End transaction called when not in a transaction")
            isInTransaction = false
        }
    }
    
    func transactionSafeSyncOnAccessQueue(execute block: () throws -> Void) rethrows {
        if isInTransaction {
            try block()
        } else {
            try queue.sync(execute: block)
        }
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
                    try db.savepoint {
                        result = try value(db)
                    }
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
        try transactionSafeSyncOnAccessQueue {
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
    func updateOnAccessQueue<T: DatabaseUpdatable>(_ queryBuilder: QueryBuilder<T>, record: T.UpdateRecord, completion: @escaping (Swift.Result<Int,Error>) -> Void) {
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
    
    @discardableResult
    func updateOnAccessQueue<T: DatabaseUpdatable>(_ queryBuilder: QueryBuilder<T>, record: T.UpdateRecord) throws -> Int {
        let db = self.db
        var updated: Int = 0
        try transactionSafeSyncOnAccessQueue {
            updated = try T.update(db, query: queryBuilder, record: record)
        }
        return updated
    }
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

extension DatabaseManager {
    func fetchOnAccessQueue<T: DatabaseFetchable>(_ queryBuilder: QueryBuilder<T>, completion: @escaping (Swift.Result<[T],Error>) -> Void) {
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
    
    func fetchOnAccessQueue<T: DatabaseFetchable>(_ queryBuilder: QueryBuilder<T>) throws -> [T] {
        let db = self.db
        var fetched = [T]()
        try transactionSafeSyncOnAccessQueue {
            fetched = try T.fetch(db, queryBuilder: queryBuilder)
        }
        return fetched
    }
}

// MARK: - Transactions

struct DatabaseTransaction<T> {
    private let block: (DatabaseManager) throws -> T
    private let db: DatabaseManager
    init(manager: DatabaseManager, _ block: @escaping (DatabaseManager) throws -> T) {
        self.db = manager
        self.block = block
    }
    
    fileprivate func run() throws -> T {
        return try block(db)
    }
}

extension DatabaseManager {
    func createTransaction<T>(block: @escaping (DatabaseManager) throws -> T) -> DatabaseTransaction<T> {
        let transaction = DatabaseTransaction(manager: self, block)
        return transaction
    }
        
    func runTransaction<T>(_ transaction: DatabaseTransaction<T>, completion: @escaping (Swift.Result<T,Error>) -> Void) {
        let db = self.db
        self.queue.async {
            self.startTransaction()
            defer {
                self.endTransaction()
            }
            var result: T? = nil
            do {
                try db.transaction {
                    result = try transaction.run()
                }
                completion(.success(result!))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
