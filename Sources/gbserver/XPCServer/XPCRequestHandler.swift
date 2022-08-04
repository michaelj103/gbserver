//
//  XPCRequestHandler.swift
//  
//
//  Created by Michael Brandt on 8/3/22.
//

import NIOCore
import Foundation

final class XPCRequestHandler: ChannelInboundHandler {
    public typealias InboundIn = XPCMessagePart
    public typealias OutboundOut = ByteBuffer
    
    private enum RequestState {
        case waitingForCommand
        case waitingForBody(command: String)
        case done
    }
    
    private var responseBuffer: ByteBuffer!
    private let database: DatabaseManager
    private let commandCenter: ServerJSONCommandCenter
    private var state = RequestState.waitingForCommand
    
    init(_ db: DatabaseManager, commandCenter: ServerJSONCommandCenter) {
        self.database = db
        self.commandCenter = commandCenter
    }
        
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inbound = unwrapInboundIn(data)
        switch inbound {
        case .command(let command):
            state = .waitingForBody(command: command)
        case .body(let bodyBuffer):
            if case .waitingForBody(let command) = state {
                let bodyData = Data(buffer: bodyBuffer, byteTransferStrategy: .noCopy)
                do {
                    try _runCommand(context: context, commandName: command, data: bodyData)
                } catch ServerJSONCommandError.unrecognizedCommand {
                    _writeErrorResponse(context: context, message: "Unrecognized command \"\(command)\"")
                } catch ServerJSONCommandError.decodeError(let underlyingError) {
                    _writeErrorResponse(context: context, message: "Command decode error \(underlyingError)")
                } catch {
                    // Not sure what could have gone wrong at this layer. Command should know (and have already logged)
                    _writeErrorResponse(context: context, message: "Command-specific error occurred for \"\(command)\": \(error)")
                }
            } else {
                print("Internal error: invalid read state")
                assertionFailure()
            }
            
            state = .done
        }
    }
    
    private func _runCommand(context: ChannelHandlerContext, commandName: String, data: Data) throws {
        let commandContext = ServerCommandContext(eventLoop: context.eventLoop, db: database)
        let responseFuture = try commandCenter.runCommand(commandName, data: data, context: commandContext)
        responseFuture.whenSuccess { data in
            self._writeResponseJSONData(context: context, data: data)
        }
        responseFuture.whenFailure { error in
            self._writeErrorResponse(context: context, message: "Command \"\(commandName)\" encountered an error: \(error)")
        }
    }
    
    private func _writeResponseJSONData(context: ChannelHandlerContext, data: Data) {
        let length = data.count
        guard length < Int32.max else {
            _writeErrorResponse(context: context, message: "Successful response is too long", allowSubError: false)
            return
        }
        responseBuffer.writeInteger(UInt8(1))
        responseBuffer.writeInteger(Int32(length))
        responseBuffer.writeData(data)
        _finalizeResponse(context: context)
    }
    
    private func _writeErrorResponse(context: ChannelHandlerContext, message: String, allowSubError: Bool = true) {
        guard let messageData = message.data(using: .utf8) else {
            precondition(allowSubError)
            _writeErrorResponse(context: context, message: "Unable to encode error message", allowSubError: false)
            return
        }
        let length = messageData.count
        guard length < Int32.max else {
            precondition(allowSubError)
            _writeErrorResponse(context: context, message: "Error response too long", allowSubError: false)
            return
        }
        
        responseBuffer.writeInteger(UInt8(0))
        responseBuffer.writeInteger(Int32(length))
        responseBuffer.writeData(messageData)
        _finalizeResponse(context: context)
    }
    
    private func _finalizeResponse(context: ChannelHandlerContext) {
        let finalPromise: EventLoopPromise<Void> = context.eventLoop.makePromise()
        context.writeAndFlush(wrapOutboundOut(responseBuffer.slice()), promise: finalPromise)
        finalPromise.futureResult.whenComplete { _ in
            context.close(promise: nil)
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        //TODO: timeout?
        responseBuffer = context.channel.allocator.buffer(capacity: 0)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("XPC Channel error: ", error)
        context.close(promise: nil)
    }
}

