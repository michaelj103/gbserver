//
//  LinkRoomManager+NIO.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import NIOCore

extension LinkRoomManager {
    func runBlock<T>(eventLoop: NIOCore.EventLoop, block: @escaping (LinkRoomManager) throws -> T) -> EventLoopFuture<T> {
        let promise = eventLoop.makePromise(of: T.self)
        runBlock {
            do {
                let result = try block(self)
                promise.succeed(result)
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
}
