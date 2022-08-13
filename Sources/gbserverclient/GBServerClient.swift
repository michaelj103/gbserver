//
//  GBServerClient.swift
//  
//
//  Created by Michael Brandt on 8/12/22.
//

import Foundation
import ArgumentParser

@main
struct GBServerClient : ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "gbserverclient",
        abstract: "CLI for testing client interactions with the GB Server",
        subcommands: [RoomCommand.self]
    )
}

