//
//  UserPayloads.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

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
        
    public var printableDisplayName: String {
        return displayName ?? "<Null>"
    }
    
    public init(deviceID: String, displayName: String?) {
        self.deviceID = deviceID
        self.displayName = displayName
    }
}

public struct RegisterUserHTTPRequestPayload: Codable {
    public let deviceID: String
    public let displayName: String?
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String, displayName: String?) {
        self.deviceID = deviceID
        self.displayName = displayName
        
        self.clientInfo = ClientInfo()
    }
}

public typealias RegisterUserXPCRequestPayload = RegisterUserHTTPRequestPayload
