//
//  UserPayloads.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

import Foundation

public struct ListUsersXPCRequestPayload: Codable {
    public let deviceID: String?
    public let displayName: String?
    
    public let clientInfo: ClientInfo?
    
    private init(deviceID: String?, displayName: String?) {
        self.deviceID = deviceID
        self.displayName = displayName
        
        self.clientInfo = ClientInfo()
    }
    
    public init(deviceID: String) {
        self.init(deviceID: deviceID, displayName: nil)
    }
    
    public init(displayName: String) {
        self.init(deviceID: nil, displayName: displayName)
    }
    
    public init() {
        self.init(deviceID: nil, displayName: nil)
    }
}

public struct ListUsersXPCResponsePayload: Codable {
    public let deviceID: String
    public let displayName: String?
    public let debugAuthorized: Bool
    public let createRoomAuthorized: Bool
        
    public var printableDisplayName: String {
        return displayName ?? "<Null>"
    }
    
    public init(deviceID: String, displayName: String?, debugAuthorized: Bool, createRoomAuthorized: Bool) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.debugAuthorized = debugAuthorized
        self.createRoomAuthorized = createRoomAuthorized
    }
}

public struct RegisterUserLegacyHTTPRequestPayload: Codable {
    public let deviceID: String
    public let displayName: String?
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String, displayName: String?) {
        self.deviceID = deviceID
        self.displayName = displayName
        
        self.clientInfo = ClientInfo()
    }
}

public typealias RegisterUserLegacyXPCRequestPayload = RegisterUserLegacyHTTPRequestPayload

public struct RegisterUserHTTPRequestPayload: Codable {
    public let apiKey: String
    public let displayName: String?
    
    public let clientInfo: ClientInfo?
    
    public init(key: String, displayName: String?) {
        self.apiKey = key
        self.displayName = displayName
        
        clientInfo = ClientInfo()
    }
}

public struct RegisterUserHTTPResponsePayload: Codable {
    public let deviceID: String
    public init(deviceID: String) {
        self.deviceID = deviceID
    }
}

public struct UpdateUserXPCRequestPayload: Codable {
    // immutable properties
    public let deviceID: String
    
    // mutable properties
    public let updatedName: NullablePropertyWrapper<String>?
    public let updatedDebugAuthorization: Bool?
    public let updateCreateRoomAuthorization: Bool?
    
    public let clientInfo: ClientInfo?
        
    public init(deviceID: String, displayName: NullablePropertyWrapper<String>?, debugAuthorized: Bool?, createRoomAuthorized: Bool?) {
        self.deviceID = deviceID
        self.updatedName = displayName
        self.updatedDebugAuthorization = debugAuthorized
        self.updateCreateRoomAuthorization = createRoomAuthorized
        
        self.clientInfo = ClientInfo()
    }
}

public struct CheckInUserHTTPRequestPayload: Codable {
    public let deviceID: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        
        self.clientInfo = ClientInfo()
    }
}

public typealias CheckInUserXPCRequestPayload = CheckInUserHTTPRequestPayload

public struct ListCheckInsXPCRequestPayload: Codable {
    public let deviceID: String
    public let maxCount: Int?
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String, maxCount: Int?) {
        self.deviceID = deviceID
        self.maxCount = maxCount
        
        self.clientInfo = ClientInfo()
    }
}

public struct ListCheckInsXPCResponsePayload: Codable {
    public let deviceID: String
    public let checkIns: [Date]
    
    public init(deviceID: String, checkIns: [Date]) {
        self.deviceID = deviceID
        self.checkIns = checkIns
    }
}

public struct UserGetDebugAuthHTTPRequestPayload: QueryDecodable {
    public let deviceID: String
    
    public init(query: [String : String]) throws {
        if let deviceID = query["deviceID"] {
            self.deviceID = deviceID
        } else {
            throw RequestDecodeError("Missing value for \"deviceID\"")
        }
    }
}

public struct UserGetDebugAuthHTTPResponsePayload: Codable {
    public let authorized: Bool
    public init(_ authorized: Bool) {
        self.authorized = authorized
    }
}

public struct VerifyUserHTTPRequestPayload: QueryDecodable {
    public let deviceID: String
    
    public init(query: [String : String]) throws {
        if let deviceID = query["deviceID"] {
            self.deviceID = deviceID
        } else {
            throw RequestDecodeError("Missing value for \"deviceID\"")
        }
    }
}

public enum VerifyUserHTTPResponsePayload: Codable {
    case userExists
    case userDoesNotExist
}

