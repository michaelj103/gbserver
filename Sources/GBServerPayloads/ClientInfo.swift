//
//  ClientInfo.swift
//  
//
//  Created by Michael Brandt on 8/7/22.
//

public struct ClientInfo: Codable {
    private static let currentAPIVersion = 1
    
    public let clientVersion: Int
    
    public init() {
        self.clientVersion = ClientInfo.currentAPIVersion
    }
}

public protocol QueryDecodable {
    init(query: [String:String]) throws
}
