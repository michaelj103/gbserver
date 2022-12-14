//
//  DatabaseManager+NIO.swift
//  
//
//  Created by Michael Brandt on 8/1/22.
//

import NIOCore
import SQLite

extension DatabaseManager {
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

