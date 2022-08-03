//
//  ServerJSONCommand.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

import NIOCore
import Foundation
import SQLite

struct ServerCommandContext {
    let eventLoop: EventLoop
    let db: DatabaseManager
}

protocol ServerJSONCommand: JSONCommand {
    func run(context: ServerCommandContext) throws -> EventLoopFuture<Data>
}
