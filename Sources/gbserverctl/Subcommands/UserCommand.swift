//
//  UserCommand.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation

import Foundation
import GBServerPayloads
import ArgumentParser

extension GBServerCTL {
    struct UserCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "user",
            subcommands: [List.self]
        )
    }
}

fileprivate extension GBServerCTL.UserCommand {
    struct List: ParsableCommand {
        
        @Option(name: .shortAndLong, help: "The user name (or pattern) to filter on.")
        var name: String?
        
        @Option(name: .shortAndLong, help: "The user deviceID (or pattern) to filter on.")
        var deviceID: String?
        
        func validate() throws {
            if name != nil && deviceID != nil {
                throw CommandError("Only one of name or deviceID may be specified")
            }
        }
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = ListXPCRequest(name: name, deviceID: deviceID)
            try connection.sendRequest(request) { result in
                switch result {
                case .success(let data):
                    List._printResult(data)
                case .failure(let error):
                    print("list failed with error: \(error)")
                }
            }
        }
        
        static private func _printResult(_ data: Data) {
            guard let result = try? JSONDecoder().decode([ListUsersXPCResponsePayload].self, from: data) else {
                print("Unable to decode response from server")
                return
            }
            
            let count = result.count
            print("Found \(count) user", terminator: count == 1 ? "\n" : "s\n")
            
            for payload in result.sorted(by: { $0.name < $1.name }) {
                print("User:")
                print("   name: \"\(payload.name)\"")
                print("   deviceID: \(payload.deviceID)")
            }
        }
        
        private struct ListXPCRequest: XPCRequest {
            typealias PayloadType = ListUsersXPCRequestPayload
            let name = "listUsers"
            let payload: ListUsersXPCRequestPayload
            
            init(name: String?, deviceID: String?) {
                if let name = name {
                    payload = ListUsersXPCRequestPayload(name: name)
                } else if let deviceID = deviceID {
                    payload = ListUsersXPCRequestPayload(deviceID: deviceID)
                } else {
                    payload = ListUsersXPCRequestPayload()
                }
            }
        }
    }
}
