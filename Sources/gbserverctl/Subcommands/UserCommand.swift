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
            subcommands: [List.self, Register.self]
        )
    }
}

fileprivate extension GBServerCTL.UserCommand {
    struct List: ParsableCommand {
        
        @Option(name: [.customShort("n"), .long], help: "The user display name (or pattern) to filter on.")
        var displayName: String?
        
        @Option(name: .shortAndLong, help: "The user deviceID (or pattern) to filter on.")
        var deviceID: String?
        
        func validate() throws {
            if displayName != nil && deviceID != nil {
                throw CommandError("Only one of name or deviceID may be specified")
            }
        }
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = ListXPCRequest(displayName: displayName, deviceID: deviceID)
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
            
            for payload in result.sorted(by: { $0.printableDisplayName < $1.printableDisplayName }) {
                print("User:")
                print("   name: \"\(payload.printableDisplayName)\"")
                print("   deviceID: \(payload.deviceID)")
            }
        }
        
        private struct ListXPCRequest: XPCRequest {
            let name = "listUsers"
            let payload: ListUsersXPCRequestPayload
            
            init(displayName: String?, deviceID: String?) {
                if let name = displayName {
                    payload = ListUsersXPCRequestPayload(displayName: name)
                } else if let deviceID = deviceID {
                    payload = ListUsersXPCRequestPayload(deviceID: deviceID)
                } else {
                    payload = ListUsersXPCRequestPayload()
                }
            }
        }
    }
}

fileprivate extension GBServerCTL.UserCommand {
    struct Register: ParsableCommand {
        
        @Option(name: [.customShort("n"), .long], help: "The user display name to register.")
        var displayName: String?
        
        @Option(name: .shortAndLong, help: "The user deviceID to register.")
        var deviceID: String
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = RegisterRequest(deviceID: deviceID, displayName: displayName)
            try connection.sendRequest(request) { result in
                switch result {
                case .success(let data):
                    Register._printResult(data)
                case .failure(let error):
                    print("list failed with error: \(error)")
                }
            }
        }
        
        static private func _printResult(_ data: Data) {
            guard let result = try? JSONDecoder().decode(GenericMessageResponse.self, from: data) else {
                print("Unable to decode response from server")
                return
            }
            
            switch result {
            case .success(let message):
                print("Received success with message: \(message)")
            case .failure(let message):
                print("Received failure with message: \(message)")
            }
        }
        
        private struct RegisterRequest: XPCRequest {
            let name = "registerUser"
            let payload: RegisterUserXPCRequestPayload
            
            init(deviceID: String, displayName: String?) {
                payload = RegisterUserXPCRequestPayload(deviceID: deviceID, displayName: displayName)
            }
        }
    }
}
