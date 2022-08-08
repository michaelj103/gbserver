//
//  GBServerCTLVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation
import GBServerPayloads
import ArgumentParser

extension GBServerCTL {
    struct VersionCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "version",
            subcommands: [List.self, Add.self]
        )
    }
}

fileprivate extension GBServerCTL.VersionCommand {
    struct List: ParsableCommand {
        
        @Option(name: .shortAndLong, help: "The type of versions to list")
        var type: VersionTypeArgument = .current
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = ListXPCRequest(self.type.versionType())
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
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode([VersionXPCResponsePayload].self, from: data) else {
                print("Unable to decode response from server")
                return
            }
            
            let count = result.count
            print("Found \(count) version", terminator: count == 1 ? "\n" : "s\n")
            
            for payload in result.sorted(by: { $0.build < $1.build }) {
                print("Version:")
                print("   name: \"\(payload.versionName)\"")
                print("   build: \(payload.build)")
                print("   type: \(payload.type)")
            }
        }
        
        private struct ListXPCRequest: XPCRequest {
            let name = "currentVersionInfo"
            let payload: VersionXPCRequestPayload
            
            init(_ type: VersionType) {
                payload = VersionXPCRequestPayload(requestedType: type)
            }
        }
    }
}

fileprivate extension GBServerCTL.VersionCommand {
    struct Add: ParsableCommand {
        @Option(name: .shortAndLong, help: "Build number of the entry to add. Must be unique.")
        var build: Int
        
        @Option(name: .shortAndLong, help: "Build name of the entry to add. Must be unique.")
        var name: String
        
        @Option(name: .shortAndLong, help: "Type of build. Any existing versions of a unique type will be moved to legacy.")
        var type: VersionTypeArgument
        
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = AddXPCRequest(build: build, name: name, type: type.versionType())
            try connection.sendRequest(request, responseHandler: { result in
                switch result {
                case .success(let data):
                    Add._printResult(data)
                case .failure(let error):
                    print("add failed with error: \(error)")
                }
            })
        }
        
        static func _printResult(_ data: Data) {
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(GenericMessageResponse.self, from: data) else {
                print("Unable to decode response from server")
                return
            }
            
            switch result {
            case .success(let message):
                print("Succeeded with message: \(message)")
            case .failure(let message):
                print("Failed with message: \(message)")
            }
        }
        
        private struct AddXPCRequest: XPCRequest {
            let name = "addVersionInfo"
            let payload: AddVersionXPCRequestPayload
            
            init(build: Int, name: String, type: VersionType) {
                payload = AddVersionXPCRequestPayload(build: Int64(build), versionName: name, type: type)
            }
        }
    }
}

fileprivate enum VersionTypeArgument: String, ExpressibleByArgument, CaseIterable {
    case legacy, current, staging
    
    func versionType() -> VersionType {
        switch self {
        case .legacy:
            return .legacy
        case .current:
            return .current
        case .staging:
            return .staging
        }
    }
}
