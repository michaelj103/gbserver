//
//  UserModel.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import SQLite
import GBServerPayloads

struct UserModel: DatabaseTable {
    let users = Table("Users")
    let id = Expression<Int64>("id")
    let deviceID = Expression<String>("deviceID")
    let name = Expression<String>("name")
    
    static func createIfNecessary(_ db: Connection) throws {
        // Not ready yet
//        let userCreation = users.create(temporary: false, ifNotExists: true, withoutRowid: false) { builder in
//            builder.column(id, primaryKey: true)
//            builder.column(deviceID, unique: true)
//            builder.column(name)
//        }
//
//        try db.run(userCreation)
    }
}

