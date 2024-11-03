//
//  ClientInfo.swift
//  
//
//  Created by Michael Brandt on 8/7/22.
//

public struct ClientInfo: Codable, Sendable {
    private static let currentAPIVersion = 2
    
    // Client version is mainly there to restrict functionality to shipped clients above a certain version
    // Obviously, anybody could construct a request and just set the version, but that's not the goal or point
    public let clientVersion: Int
    
    public init() {
        self.clientVersion = ClientInfo.currentAPIVersion
    }
}

public protocol QueryDecodable {
    init(query: [String:String]) throws
}
