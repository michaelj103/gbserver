//
//  KeyGenerator.swift
//  
//
//  Created by Michael Brandt on 8/10/22.
//

import Foundation
import Crypto

struct KeyGenerator {
    enum DataEncoding {
        case base64
        case base32
    }
    
    static func generateKey(size: SymmetricKeySize, encoding: DataEncoding = .base64) -> String {
        let secret = SymmetricKey(size: size)
        let secretData = secret.withUnsafeBytes { pointer -> Data in
            let bufferPointer = pointer.bindMemory(to: UInt8.self)
            let data = Data(buffer: bufferPointer)
            return data
        }
        let key: String
        switch encoding {
        case .base64:
            key = secretData.base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
        case .base32:
            key = secretData.base32EncodedString()
        }
        
        return key
    }
}

fileprivate extension Data {
    func base32EncodedString() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".map { $0 }
        assert(characters.count == 32)
        var pendingEncode: UInt16 = 0
        var bitsPending = 0
        var string = String()
        for byte in self {
            pendingEncode <<= 8
            pendingEncode |= UInt16(byte)
            bitsPending += 8
            
            while bitsPending >= 5 {
                bitsPending -= 5
                let byteVal = Int((pendingEncode >> bitsPending) & 0x1F)
                string.append(characters[byteVal])
            }
        }
        return string
    }
}
