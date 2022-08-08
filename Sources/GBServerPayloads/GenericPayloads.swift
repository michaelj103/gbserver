//
//  GenericPayloads.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

public enum GenericMessageResponse: Codable {
    case success(message: String)
    case failure(message: String)
}

