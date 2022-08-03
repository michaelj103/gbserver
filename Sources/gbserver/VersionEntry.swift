//
//  VersionEntry.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import SQLite

struct VersionEntry: DatabaseFetchable, Encodable {
    let id: Int64
    let build: Int64
    let versionName: String
    let type: VersionType
    
    private enum CodingKeys: String, CodingKey {
        case build, versionName
    }
    
    static let table = Table("Versions")
    static let id = Expression<Int64>("id")
    static let build = Expression<Int64>("build")
    static let versionName = Expression<String>("versionName")
    static let type = Expression<Int64>("type")
    
    static func fetch(queryBuilder: QueryBuilder<VersionEntry>, db: Connection) throws -> [VersionEntry] {
        let query = queryBuilder.query
        let rowIterator = try db.prepareRowIterator(query)
        let entries: [VersionEntry] = try rowIterator.map({ element in
            let entry = VersionEntry(id: element[id], build: element[build], versionName: element[versionName], type: try _type(element[type]))
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
}

enum VersionType: Int64, Encodable {
    case legacy = 0
    case current = 1
    case staging = 2
}
