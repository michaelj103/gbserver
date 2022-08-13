//
//  RoomCommand.swift
//  
//
//  Created by Michael Brandt on 8/12/22.
//

import Foundation
import ArgumentParser
import NIOHTTP1
import NIOFoundationCompat
import GBServerPayloads

extension GBServerClient {
    struct RoomCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "room",
            subcommands: [Create.self]
        )
    }
}

fileprivate extension GBServerClient.RoomCommand {
    struct Create: ParsableCommand {
        mutating func run() throws {
            let session = HTTPSession(host: "localhost", port: 8080)
            session.keepAlive()
            
            let connection = try session.makeConnection()
            let payload = CreateRoomHTTPRequestPayload(deviceID: "abcdefg")
            let data = try JSONEncoder().encode(payload)
            
            var headerFields = HTTPHeaders()
            headerFields.add(name: "Content-Type", value: "application/json; charset=utf-8")
            headerFields.add(name: "Content-Length", value: "\(data.count)")
            
            let header = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/api/createRoom", headers: headerFields)
            connection.write(header: header, body: data)
            
            connection.setCloseCallback { _ in
                session.stopKeepAlive()
                Create.exit(withError: nil)
            }
            
            Dispatch.dispatchMain()
        }
    }
}
