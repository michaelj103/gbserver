//
//  GBServerCTLVersionCommand.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import NIOCore
import NIOPosix
import NIOFoundationCompat
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
        mutating func run() throws {
            let connectionManager = XPCConnectionManager()
            let connection = try connectionManager.makeConnection()
            
            let request = ListXPCRequest(.current)
            try connection.sendRequest(request) { result in
                switch result {
                case .success(let data):
                    List._printResult(data)
                case .failure(let error):
                    print("\"list\" failed with error: \(error)")
                }
            }
        }
        
        static private func _printResult(_ data: Data) {
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode([VersionXPCResponsePayload].self, from: data) else {
                print("Unable to decode response from server")
                return
            }
                        
            for payload in result.sorted(by: { $0.build < $1.build }) {
                print("Version:")
                print("   name: \"\(payload.versionName)\"")
                print("   build: \(payload.build)")
                print("   type: \(payload.type)")
            }
        }
    }
    
    private struct ListXPCRequest: XPCRequest {
        typealias PayloadType = VersionXPCRequestPayload
        let name = "currentVersionInfo"
        let payload: VersionXPCRequestPayload
        
        init(_ type: VersionType) {
            payload = VersionXPCRequestPayload(requestedType: type)
        }
    }
}

fileprivate extension GBServerCTL.VersionCommand {
    struct Add: ParsableCommand {
        mutating func run() throws {
            print("Add not implemented")
        }
    }
}
