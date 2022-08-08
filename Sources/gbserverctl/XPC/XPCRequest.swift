//
//  XPCRequest.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import Foundation
import NIOCore

protocol XPCRequest {
    associatedtype PayloadType: Encodable
    
    var name: String { get }
    var payload: PayloadType { get }
    func encode(with encoder: JSONEncoder, to buffer: inout ByteBuffer) throws
}

extension XPCRequest {
    func encode(with encoder: JSONEncoder, to buffer: inout ByteBuffer) throws {
        let name = self.name
        let nameLength = Int16(name.count)
        let payload = self.payload
        let payloadData = try encoder.encode(payload)
        let payloadLength = Int16(payloadData.count)
                
        // Write everything once we are sure it all encoded successfully
        buffer.writeString("MSG")
        buffer.writeInteger(nameLength)
        buffer.writeInteger(payloadLength)
        buffer.writeString(name)
        buffer.writeData(payloadData)
    }
}
