//
//  main.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import NIOCore
import NIOPosix
import NIOFoundationCompat
import Foundation

private final class PrintHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    private func printByte(_ byte: UInt8) {
        fputc(Int32(byte), stdout)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = self.unwrapInboundIn(data)
        while let byte: UInt8 = buffer.readInteger() {
            printByte(byte)
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        print("Read Complete")
    }
    
    func channelUnregistered(context: ChannelHandlerContext) {
        print("Unregistered")
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)

        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }
}

let path = "/tmp/com.mjb.gbserver"
let threadGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let bootstrap = ClientBootstrap(group: threadGroup)
    // Enable SO_REUSEADDR.
    .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .channelInitializer { channel in
        channel.pipeline.addHandler(PrintHandler())
    }

let channel = try bootstrap.connect(unixDomainSocketPath: path).wait()

print("Connected...")

let jsonPacket = Dictionary<String, String>()
let jsonData = try JSONEncoder().encode(jsonPacket)
var buffer = channel.allocator.buffer(string: "MSG")
precondition(buffer.writeInteger(Int16(5)) == 2)
precondition(buffer.writeInteger(Int16(jsonData.count)) == 2)
buffer.writeString("Hello")
buffer.writeData(jsonData)
try! channel.writeAndFlush(buffer.slice()).wait()

try! channel.closeFuture.wait()


print("Done?")
