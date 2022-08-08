//
//  main.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import ArgumentParser

@main
struct GBServerCTL : ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "gbserverctl",
        abstract: "CLI for interfacing with the GB Server",
        subcommands: [VersionCommand.self]
    )
}
