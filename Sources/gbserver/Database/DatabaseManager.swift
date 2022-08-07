//
//  DatabaseManager.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import GRDB

class DatabaseManager {
    let dbQueue: DatabaseQueue
    private let tables: [DatabaseTable.Type]
    
    init(_ location: DatabaseLocation, tables: [DatabaseTable.Type]) throws {
        switch location {
        case .inMemory:
            dbQueue = DatabaseQueue()
        case .onDisk(let path):
            dbQueue = try DatabaseQueue(path: path)
        }
    }
    
    func performInitialSetup() throws {
        for table in tables {
            try table.createTableIfNecessary(dbQueue)
        }
    }
}

enum DatabaseLocation {
    case inMemory
    case onDisk(String)
}

protocol DatabaseTable {
    // TODO: I bet we could do this way more automatically in swift with property wrappers, etc
    static func createTableIfNecessary(_ dbQueue: DatabaseQueue) throws
}
