//
//  GenericPayloads.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

public enum GenericMessageResponse: Codable {
    case success(message: String)
    case failure(message: String)
    
    // For clients who don't really care about success or failure
    public func getMessage() -> String {
        switch self {
        case .success(let message):
            return message
        case .failure(let message):
            return message
        }
    }
}

// Allows clients optionally provide a value for a nullable property because nil is already taken
// e.g. you can update either the displayName (nullable) or username or both. We have to distinguish between
// the case where you want to set the displayName to nil and the case where you don't want to update displayName at all
public struct NullablePropertyWrapper<T: Codable & Sendable>: Codable, Sendable {
    public let value: T?
    public init(_ t: T?) {
        self.value = t
    }
}

