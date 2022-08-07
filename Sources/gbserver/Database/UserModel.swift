//
//  UserModel.swift
//  
//
//  Created by Michael Brandt on 8/7/22.
//

import Foundation
import GRDB

struct UserModel: Codable, DatabaseTable, FetchableRecord, MutablePersistableRecord {
    private(set) var id: Int64?
    let deviceID: String
    let displayName: String?
    
    static let databaseTableName: String = "users"
    
    private static let idColumnName = "id"
    private static let deviceIDColumnName = "deviceID"
    private static let displayNameColumnName = "displayName"
    
    static let deviceIDColumn = Column(deviceIDColumnName)
    static let displayNameColumn = Column(displayNameColumnName)
    
    static func createTableIfNecessary(_ dbQueue: DatabaseQueue) throws {
        try dbQueue.write({ db in
            try db.create(table: databaseTableName, options: .ifNotExists, body: { tableDefinition in
                tableDefinition.autoIncrementedPrimaryKey(idColumnName)
                tableDefinition.column(deviceIDColumnName).notNull().unique()
                tableDefinition.column(displayNameColumnName).unique()
            })
        })
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

