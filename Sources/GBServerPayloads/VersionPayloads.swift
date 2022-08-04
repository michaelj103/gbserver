//
//  VersionPayloads.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation

public struct CurrentVersionHTTPRequestPayload: Codable {
    public let requestedType: VersionType?
}

public struct CurrentVersionHTTPResponsePayload : Codable {
    public let build: Int64
    public let versionName: String
    public let type: VersionType
    
    public init(build: Int64, versionName: String, type: VersionType) {
        self.build = build
        self.versionName = versionName
        self.type = type
    }
}

public typealias VersionXPCRequestPayload = CurrentVersionHTTPResponsePayload
public typealias VersionXPCResponsePayload = CurrentVersionHTTPRequestPayload

//TODO: can this really live here?
public enum VersionType: Int64, Codable, CustomStringConvertible {
    case legacy = 0
    case current = 1
    case staging = 2
    
    public var description: String {
        switch self {
        case .legacy:
            return "legacy"
        case .current:
            return "current"
        case .staging:
            return "staging"
        }
    }
}

