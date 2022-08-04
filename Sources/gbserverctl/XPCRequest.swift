//
//  XPCRequest.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation

protocol XPCRequest {
    associatedtype PayloadType: Encodable
    
    var payload: PayloadType { get }
    func encode(_ with: JSONEncoder)
}
