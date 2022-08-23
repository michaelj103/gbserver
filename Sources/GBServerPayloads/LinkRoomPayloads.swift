//
//  LinkRoomPayloads.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

// MARK: - Requests

/// Request payload for creating a room. Successful response is LinkRoomClientInfo
public struct CreateRoomHTTPRequestPayload: Codable {
    public let deviceID: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        
        clientInfo = ClientInfo()
    }
}

/// Request payload for closing a room that you created. Successful response is GenericMessageResponse
public struct CloseRoomHTTPRequestPayload: Codable {
    public let deviceID: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        
        clientInfo = ClientInfo()
    }
}

/// Request payload for joining a room that a different user created using a join code. Successful response is LinkRoomClientInfo
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

/// Request payload for getting a room that a user is currently a member of, if any. Successful response is PossibleLinkRoomClientInfo
public struct GetRoomInfoHTTPRequestPayload: Codable, QueryDecodable {
    public let deviceID: String
    
    public let clientInfo: ClientInfo?
    
    public init(deviceID: String) {
        self.deviceID = deviceID
        
        clientInfo = ClientInfo()
    }
    
    public init(query: [String : String]) throws {
        clientInfo = nil
        if let deviceID = query["deviceID"] {
            self.deviceID = deviceID
        } else {
            throw RequestDecodeError("Missing value for \"deviceID\"")
        }
    }
}

// MARK: - Responses

public enum LinkRoomKey: Codable {
    case owner(String)
    case participant(String)
    
    public var stringValue: String {
        switch self {
        case .owner(let string):
            return string
        case .participant(let string):
            return string
        }
    }
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

public enum PossibleLinkRoomClientInfo: Codable {
    case isInRoom(LinkRoomClientInfo)
    case isNotInRoom
}

