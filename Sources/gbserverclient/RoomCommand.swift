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
import GBLinkServerProtocol

extension GBServerClient {
    struct RoomCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "room",
            subcommands: [Create.self, Connect.self, Join.self, Close.self, Get.self]
        )
    }
}

fileprivate extension GBServerClient.RoomCommand {
    struct Create: ParsableCommand {
        @Option(help: "Server host address. Defaults to 'localhost'")
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
            
            connection.setBodyDataCallback { data in
                if let response = try? JSONDecoder().decode(LinkRoomClientInfo.self, from: data) {
                    print(response)
                } else {
                    print("Failed to decode response")
                }
            }
            connection.setBodyTextCallback { text in
                print("Text response: \(text)")
            }
            
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
    struct Join: ParsableCommand {
        @Option(help: "Server host address. Defaults to 'localhost'")
        var host: String = "localhost"
        
        @Option(name: .shortAndLong, help: "Server host port. Defaults to 8080")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Device ID of requesting user")
        var deviceID: String
        
        @Option(name: NameSpecification([.customShort("c"), .customLong("join-code")]), help: "Room code for joining")
        var joinCode: String
        
        mutating func run() throws {
            let session = HTTPSession(host: host, port: port)
            session.keepAlive()
            
            let connection = try session.makeConnection()
            let payload = JoinRoomHTTPRequestPayload(deviceID: deviceID, roomCode: joinCode)
            let data = try JSONEncoder().encode(payload)
            
            connection.setBodyDataCallback { data in
                if let response = try? JSONDecoder().decode(LinkRoomClientInfo.self, from: data) {
                    print(response)
                } else {
                    print("Failed to decode response")
                }
            }
            connection.setBodyTextCallback { text in
                print("Text response: \(text)")
            }
            
            var headerFields = HTTPHeaders()
            headerFields.add(name: "Content-Type", value: "application/json; charset=utf-8")
            headerFields.add(name: "Content-Length", value: "\(data.count)")
            
            let header = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/api/joinRoom", headers: headerFields)
            connection.write(header: header, body: data)
            
            connection.setCloseCallback { _ in
                session.stopKeepAlive()
                Join.exit(withError: nil)
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
            
            let bytes = code.map { $0.asciiValue! }
            connection.write([1] + bytes)
            
            let roomSession = InteractiveRoomSession(connection: connection)
            roomSession.keepAlive()
            
            connection.setCloseCallback { _ in
                print("Connection closed.")
                session.stopKeepAlive()
                roomSession.stopKeepAlive()
                Connect.exit(withError: nil)
            }
            
            roomSession.start()
            
            Dispatch.dispatchMain()
        }
    }
}

fileprivate extension GBServerClient.RoomCommand {
    struct Close: ParsableCommand {
        @Option(help: "Server host address. Defaults to 'localhost'")
        var host: String = "localhost"
        
        @Option(name: .shortAndLong, help: "Server host port. Defaults to 8080")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Device ID of requesting user")
        var deviceID: String
        
        mutating func run() throws {
            let session = HTTPSession(host: host, port: port)
            session.keepAlive()
            
            let connection = try session.makeConnection()
            let payload = CloseRoomHTTPRequestPayload(deviceID: deviceID)
            let data = try JSONEncoder().encode(payload)
            
            connection.setBodyDataCallback { data in
                if let response = try? JSONDecoder().decode(GenericMessageResponse.self, from: data) {
                    print(response)
                } else {
                    print("Failed to decode response")
                }
            }
            connection.setBodyTextCallback { text in
                print("Text response: \(text)")
            }
            
            var headerFields = HTTPHeaders()
            headerFields.add(name: "Content-Type", value: "application/json; charset=utf-8")
            headerFields.add(name: "Content-Length", value: "\(data.count)")
            
            let header = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/api/closeRoom", headers: headerFields)
            connection.write(header: header, body: data)
            
            connection.setCloseCallback { _ in
                session.stopKeepAlive()
                Close.exit(withError: nil)
            }
            
            Dispatch.dispatchMain()
        }
    }
}

fileprivate extension GBServerClient.RoomCommand {
    struct Get: ParsableCommand {
        @Option(help: "Server host address. Defaults to 'localhost'")
        var host: String = "localhost"
        
        @Option(name: .shortAndLong, help: "Server host port. Defaults to 8080")
        var port: Int = 8080
        
        @Option(name: .shortAndLong, help: "Device ID of requesting user")
        var deviceID: String
        
        mutating func run() throws {
            let session = HTTPSession(host: host, port: port)
            session.keepAlive()
            
            let connection = try session.makeConnection()
            let payload = GetRoomInfoHTTPRequestPayload(deviceID: deviceID)
            let data = try JSONEncoder().encode(payload)
            
            connection.setBodyDataCallback { data in
                if let response = try? JSONDecoder().decode(PossibleLinkRoomClientInfo.self, from: data) {
                    print(response)
                } else {
                    print("Failed to decode response")
                }
            }
            connection.setBodyTextCallback { text in
                print("Text response: \(text)")
            }
            
            var headerFields = HTTPHeaders()
            headerFields.add(name: "Content-Type", value: "application/json; charset=utf-8")
            headerFields.add(name: "Content-Length", value: "\(data.count)")
            
            let header = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/api/getRoomInfo", headers: headerFields)
            connection.write(header: header, body: data)
            
            connection.setCloseCallback { _ in
                session.stopKeepAlive()
                Get.exit(withError: nil)
            }
            
            Dispatch.dispatchMain()
        }
    }
}
