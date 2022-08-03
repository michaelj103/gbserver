//
//  CodablePropertyWrappers.swift
//  
//
//  Created by Michael Brandt on 8/2/22.
//

@propertyWrapper
public struct CodableIgnored<T>: Codable {
    public var wrappedValue: T?
        
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        self.wrappedValue = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        // Do nothing
    }
}

@propertyWrapper
public struct DecodableIgnored<T>: Decodable {
    public var wrappedValue: T?
        
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        self.wrappedValue = nil
    }
}

@propertyWrapper
public struct EncodableIgnored<T>: Encodable {
    public var wrappedValue: T?
        
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    public func encode(to encoder: Encoder) throws {
        // Do nothing
    }
}

extension KeyedDecodingContainer {
    public func decode<T>(
        _ type: CodableIgnored<T>.Type,
        forKey key: Self.Key) throws -> CodableIgnored<T> {
        return CodableIgnored(wrappedValue: nil)
    }
    
    public func decode<T>(
        _ type: DecodableIgnored<T>.Type,
        forKey key: Self.Key) throws -> DecodableIgnored<T> {
        return DecodableIgnored(wrappedValue: nil)
    }
}

extension KeyedEncodingContainer {
    public mutating func encode<T>(
        _ value: CodableIgnored<T>,
        forKey key: KeyedEncodingContainer<K>.Key) throws {
        // Do nothing
    }
    
    public mutating func encode<T>(
        _ value: EncodableIgnored<T>,
        forKey key: KeyedEncodingContainer<K>.Key) throws {
        // Do nothing
    }
}
