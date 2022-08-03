//
//  DatabaseManager+NIO.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import NIOCore
import SQLite

extension DatabaseManager {
    func runFetch<T: DatabaseFetchable>(eventLoop: NIOCore.EventLoop, queryBuilder: QueryBuilder<T>) -> EventLoopFuture<[T]> {
        let promise = eventLoop.makePromise(of: [T].self)
        
        fetchOnAccessQueue(queryBuilder) { result in
            switch result {
            case .success(let fetched):
                promise.succeed(fetched)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
}

