//
//  DatabaseManager+NIO.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import NIOCore
import SQLite

extension DatabaseManager {
    //TODO: Deprecated
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
    
    //TODO: Deprecated
    func runInsert<T: DatabaseInsertable>(eventLoop: NIOCore.EventLoop, type: T.Type, insertion: T.InsertRecord) -> EventLoopFuture<Int64> {
        let promise = eventLoop.makePromise(of: Int64.self)
        insertOnAccessQueue(type, insertion: insertion) { result in
            switch result {
            case .success(let rowID):
                promise.succeed(rowID)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func asyncWrite<T>(eventLoop: NIOCore.EventLoop, updates: @escaping (Connection) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        asyncWrite(updates) { result in
            switch result {
            case .success(let output):
                promise.succeed(output)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func asyncRead<T>(eventLoop: NIOCore.EventLoop, value: @escaping (Connection) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        asyncRead(value) { result in
            switch result {
            case .success(let output):
                promise.succeed(output)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
}

