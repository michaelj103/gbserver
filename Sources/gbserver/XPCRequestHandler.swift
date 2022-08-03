//
//  XPCRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import NIOCore

final class XPCRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>
}

