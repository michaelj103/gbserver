//
//  main.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import ArgumentParser
import GBServerPayloads

@main
struct GBServerCTL : ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "gbserverctl",
        abstract: "CLI for interfacing with the GB Server",
        subcommands: [VersionCommand.self, UserCommand.self, CheckInCommand.self]
    )
    
    static func printGenericResponse(_ data: Data) {
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
}
