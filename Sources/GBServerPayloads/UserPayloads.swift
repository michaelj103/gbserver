//
//  UserPayloads.swift
//  
//
//  Created by Michael Brandt on 8/5/22.
//

public struct ListUsersXPCRequestPayload: Codable {
    public let deviceID: String?
    public let name: String?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        self.name = nil
    }
    
    public init(name: String) {
        self.deviceID = nil
        self.name = name
    }
    
    public init() {
        self.deviceID = nil
        self.name = nil
    }
}

public struct ListUsersXPCResponsePayload: Codable {
    public let deviceID: String
    public let name: String
    
    public init(deviceID: String, name: String) {
        self.deviceID = deviceID
        self.name = name
    }
}

public struct RegisterUserHTTPRequestPayload: Codable {
    public let deviceID: String
    public let name: String?
    
    public init(deviceID: String, name: String?) {
        self.deviceID = deviceID
        self.name = name
    }
}
