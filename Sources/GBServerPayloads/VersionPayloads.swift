//
//  VersionPayloads.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

public struct CurrentVersionHTTPRequestPayload: Codable, QueryDecodable {
    public let requestedType: VersionType?
    
    public let clientInfo: ClientInfo?
    
    public init(requestedType: VersionType?) {
        self.requestedType = requestedType
        
        self.clientInfo = ClientInfo()
    }
    
    public init(query: [String:String]) throws {
        if let requestedType = query["requestedType"] {
            if let rawValue = Int64(requestedType), let versionType = VersionType(rawValue: rawValue) {
                self.requestedType = versionType
            } else {
                throw RequestDecodeError("Bad value for \"requestedType\": \"\(requestedType)\"")
            }
        } else {
            // No value specified
            self.requestedType = nil
        }
        
        self.clientInfo = ClientInfo()
    }
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

public typealias VersionXPCRequestPayload = CurrentVersionHTTPRequestPayload
public typealias VersionXPCResponsePayload = CurrentVersionHTTPResponsePayload
public typealias AddVersionXPCRequestPayload = CurrentVersionHTTPResponsePayload

public struct PromoteVersionXPCRequestPayload : Codable {
    public let name: String?
    
    public init(name: String?) {
        self.name = name
    }
}

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
    
    public var isSingletonType: Bool {
        switch self {
        case .legacy:
            return false
        case .current:
            return true
        case .staging:
            return true
        }
    }
}

