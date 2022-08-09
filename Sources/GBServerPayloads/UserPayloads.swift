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

public struct UpdateUserXPCRequestPayload: Codable {
    // immutable properties
    public let deviceID: String
    
    // mutable properties
    public let updatedName: NullablePropertyWrapper<String>?
    
    public let clientInfo: ClientInfo?
        
    public init(deviceID: String, displayName: String?) {
        self.deviceID = deviceID
        self.updatedName = NullablePropertyWrapper(displayName)
        
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
