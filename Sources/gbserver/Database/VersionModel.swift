//
//  File.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation
import GRDB
import GBServerPayloads

struct VersionModel: Codable, DatabaseTable, FetchableRecord, MutablePersistableRecord {
    private (set) var id: Int64?
    let build: Int64
    let versionName: String
    let type: VersionType
    
    static let databaseTableName: String = "version"
    
    private static let idColumnName = "id"
    private static let buildColumnName = "build"
    private static let versionNameColumnName = "versionName"
    private static let typeColumnName = "type"
    
    static let buildColumn = Column(buildColumnName)
    static let versionNameColumn = Column(versionNameColumnName)
    static let typeColumn = Column(typeColumnName)
    
    static func createTableIfNecessary(_ dbQueue: DatabaseQueue) throws {
        try dbQueue.write({ db in
            try db.create(table: databaseTableName, options: .ifNotExists, body: { tableDefinition in
                tableDefinition.autoIncrementedPrimaryKey(idColumnName)
                tableDefinition.column(buildColumnName, .integer).notNull().unique()
                tableDefinition.column(versionNameColumnName, .text).notNull().unique()
                tableDefinition.column(typeColumnName, .integer).notNull()
            })
        })
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}
