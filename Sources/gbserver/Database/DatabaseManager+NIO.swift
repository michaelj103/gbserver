//
//  DatabaseManager+NIO.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import NIOCore
import GRDB

extension DatabaseManager {
    func asyncWrite<T>(eventLoop: NIOCore.EventLoop, updates: @escaping (Database) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        dbQueue.asyncWrite(updates) { _, result in
            switch result {
            case .success(let output):
                promise.succeed(output)
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
    func asyncRead<T>(eventLoop: NIOCore.EventLoop, value: @escaping (Result<Database, Error>) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        dbQueue.asyncRead { result in
            switch result {
            case .success(_):
                do {
                    let output = try value(result)
                    promise.succeed(output)
                } catch {
                    promise.fail(error)
                }
            case .failure(let error):
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
    
//    func runFetch<T: DatabaseFetchable>(eventLoop: NIOCore.EventLoop, queryBuilder: QueryBuilder<T>) -> EventLoopFuture<[T]> {
//        let promise = eventLoop.makePromise(of: [T].self)
//
//        fetchOnAccessQueue(queryBuilder) { result in
//            switch result {
//            case .success(let fetched):
//                promise.succeed(fetched)
//            case .failure(let error):
//                promise.fail(error)
//            }
//        }
//        return promise.futureResult
//    }
//
//    func runInsert<T: DatabaseInsertable>(eventLoop: NIOCore.EventLoop, type: T.Type, insertion: T.InsertRecord) -> EventLoopFuture<Int64> {
//        let promise = eventLoop.makePromise(of: Int64.self)
//        insertOnAccessQueue(type, insertion: insertion) { result in
//            switch result {
//            case .success(let rowID):
//                promise.succeed(rowID)
//            case .failure(let error):
//                promise.fail(error)
//            }
//        }
//        return promise.futureResult
//    }
}

