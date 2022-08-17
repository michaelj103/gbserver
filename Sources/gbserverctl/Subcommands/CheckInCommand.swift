//
//  CheckInCommand.swift
//  
//
//  Created by Michael Brandt on 8/8/22.
//

import Foundation
import GBServerPayloads
import ArgumentParser

extension GBServerCTL {
    struct CheckInCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "checkin",
            subcommands: [List.self, Make.self]
        )
    }
}

// MARK: - Listing Checkins

fileprivate extension GBServerCTL.CheckInCommand {
    struct List: ParsableCommand {
        @Option(name: .shortAndLong, help: "The user deviceID to show checkins for.")
        var deviceID: String
        
        @Option(name: .shortAndLong, help: "The max number of checkins to show.")
        var count: Int?
        
        func validate() throws {
            if let count = count {
                if count <= 0 {
                    throw CommandError("Count must be > 0")
                }
            }
        }
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = ListXPCRequest(deviceID: deviceID, count: count)
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
            if let result = try? JSONDecoder().decode(ListCheckInsXPCResponsePayload.self, from: data) {
                let count = result.checkIns.count
                print("Found \(count) checkin", terminator: count == 1 ? "\n" : "s\n")
                for checkIn in result.checkIns {
                    print("Date: \(checkIn.date) - \(checkIn.version)")
                }
                
            } else if let result = try? JSONDecoder().decode(GenericMessageResponse.self, from: data) {
                print("Message from server: \(result.getMessage())")
            } else {
                print("Unable to decode response from server")
            }
        }
        
        private struct ListXPCRequest: XPCRequest {
            let name = "listCheckIns"
            let payload: ListCheckInsXPCRequestPayload
            
            init(deviceID: String, count: Int?) {
                payload = ListCheckInsXPCRequestPayload(deviceID: deviceID, maxCount: count)
            }
        }
    }
}

// MARK: - Making Checkins

fileprivate extension GBServerCTL.CheckInCommand {
    struct Make: ParsableCommand {
        @Option(name: .shortAndLong, help: "The user deviceID check in.")
        var deviceID: String
        
        @Option(name: .shortAndLong, help: "Version string to check in.")
        var version: String?
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = MakeXPCRequest(deviceID: deviceID, version: version)
            try connection.sendRequest(request) { result in
                switch result {
                case .success(let data):
                    Make._printResult(data)
                case .failure(let error):
                    print("make failed with error: \(error)")
                }
            }
        }
        
        static private func _printResult(_ data: Data) {
            guard let result = try? JSONDecoder().decode(GenericMessageResponse.self, from: data) else {
                print("Unable to decode response from server")
                return
            }
            
            print(result.getMessage())
        }
        
        private struct MakeXPCRequest: XPCRequest {
            let name = "checkIn"
            let payload: CheckInUserXPCRequestPayload
            
            init(deviceID: String, version: String?) {
                payload = CheckInUserXPCRequestPayload(deviceID: deviceID, version: version)
            }
        }
    }
}
