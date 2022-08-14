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
            subcommands: [Create.self, Connect.self]
        )
    }
}

fileprivate extension GBServerClient.RoomCommand {
    struct Create: ParsableCommand {
        @Option(name: .shortAndLong, help: "Server host address. Defaults to 'localhost'")
        var host: String = "localhost"
        
        @Option(name: .shortAndLong, help: "Server host port. Defaults to 8080")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Device ID of requesting user")
        var deviceID: String
        
        mutating func run() throws {
            let session = HTTPSession(host: host, port: port)
            session.keepAlive()
            
            let connection = try session.makeConnection()
            let payload = CreateRoomHTTPRequestPayload(deviceID: deviceID)
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

fileprivate extension GBServerClient.RoomCommand {
    struct Connect: ParsableCommand {
        @Option(name: .shortAndLong, help: "Join code for a user")
        var code: String
        
        @Option(name: .shortAndLong, help: "Port to use to contact the server")
        var port: Int
        
        mutating func run() throws {
            let session = LinkClientSession(host: "localhost", port: port)
            session.keepAlive()
            let connection = try session.makeConnection()
            
            connection.write([0, 1, 2, 3, 4, 5, 6])
            
            connection.setCloseCallback { _ in
                session.stopKeepAlive()
                Create.exit(withError: nil)
            }
            
            Dispatch.dispatchMain()
        }
    }
}
