//
//  ServerJSONCommand.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

import Foundation
import NIOCore

struct ServerCommandContext {
    let eventLoop: EventLoop
    let db: DatabaseManager
}

protocol ServerJSONCommand: JSONCommand {
    func run(context: ServerCommandContext) throws -> EventLoopFuture<Data>
}
