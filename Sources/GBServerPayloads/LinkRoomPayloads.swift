//
//  LinkRoomPayloads.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

public enum LinkRoomState: Int64, Codable {
    case active = 0
    case closed = 1
    case expired = 2
}

public struct CreateRoomHTTPRequestPayload: Codable {
    public let deviceID: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        
        clientInfo = ClientInfo()
    }
}

public struct JoinRoomHTTPRequestPayload: Codable {
    public let deviceID: String
    public let roomCode: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String, roomCode: String) {
        self.deviceID = deviceID
        self.roomCode = roomCode
        
        clientInfo = ClientInfo()
    }
}

public enum LinkRoomKey: Codable {
    case owner(String)
    case participant(String)
}

public struct LinkRoomClientInfo: Codable {
    public let roomID: Int
    public let roomCode: String
    public let roomKey: LinkRoomKey
    public let linkPort: Int
    
    public init(roomID: Int, roomCode: String, roomKey: LinkRoomKey, linkPort: Int) {
        self.roomID = roomID
        self.roomCode = roomCode
        self.roomKey = roomKey
        self.linkPort = linkPort
    }
}

