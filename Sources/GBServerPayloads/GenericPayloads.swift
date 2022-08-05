//
//  GenericPayloads.swift
//  
//
//  Created by Michael Brandt on 8/4/22.
//

import Foundation

public struct GenericSuccessResponse: Codable {
    public let message: String
    public init(message: String) {
        self.message = message
    }
}
