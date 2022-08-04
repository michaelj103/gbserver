//
//  HTTPRequestHandler.swift
//  
//
//  Created by Michael Brandt on 7/31/22.
//

import NIOCore
import NIOHTTP1
import NIOFoundationCompat
import Foundation

import Dispatch

final class HTTPRequestHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var buffer: ByteBuffer!
    private var defaultHeaders: HTTPHeaders!
    
    // current request state
    private var requestHeader: HTTPRequestHead?
    private var hasProcessed = false
    
    private let database: DatabaseManager
    private let commandCenter = ServerJSONCommandCenter() //TODO: inject
    init(_ db: DatabaseManager) {
        database = db
        commandCenter.registerCommand(CurrentVersionCommand())
    }
    
    // MARK: ChannelInboundHandler Lifecycle
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let header):
            requestHeader = header
        case .body(let requestBody):
            _processRequest(context: context, requestBody: requestBody)
        case .end(_):
            _processRequest(context: context, requestBody: nil)
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    // Lifecycle call: when the handler is added to the pipeline
    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
        defaultHeaders = HTTPHeaders()
        defaultHeaders.add(name: "Connection", value: "close")
    }
    
    // MARK: Internal response handling
    
    private func _processRequest(context: ChannelHandlerContext, requestBody: ByteBuffer?) {
        guard !hasProcessed else {
            return
        }
        guard let requestHeader = requestHeader else {
            print("Somehow reached the processing phase without a header")
            _sendEmptyStatus(context: context, status: .internalServerError)
            return
        }
        // Use Foundation's URL for parsing
        guard let url = URL(string: requestHeader.uri) else {
            print("Unable to parse as URL \(requestHeader.uri)")
            _sendEmptyStatus(context: context, status: .internalServerError)
            return
        }
        hasProcessed = true
        
        let apiPrefix = "/api/"
        let relativePath = url.relativePath
        if !relativePath.hasPrefix(apiPrefix) {
            _sendEmptyStatus(context: context, status: .notFound)
        } else {
            let commandString = String(relativePath.dropFirst(apiPrefix.count))
            //TODO: replace this
            let bodyData: Data = requestBody.map { Data(buffer: $0, byteTransferStrategy: .noCopy) } ?? "{}".data(using: .utf8)!
            do {
                try _runCommand(context: context, commandName: commandString, data: bodyData)
            } catch ServerJSONCommandError.unrecognizedCommand {
                print("Unrecognized command \(commandString)")
                _sendEmptyStatus(context: context, status: .badRequest)
            } catch ServerJSONCommandError.decodeError(let underlyingError) {
                print("Command decode error \(underlyingError)")
                _sendEmptyStatus(context: context, status: .badRequest)
            } catch {
                // Not sure what could have at this layer. Command should know (and have already logged)
                print("Command-specific error occurred for \(commandString): \(error)")
                _sendEmptyStatus(context: context, status: .internalServerError)
            }
        }
    }
    
    private func _runCommand(context: ChannelHandlerContext, commandName: String, data: Data) throws {
        let commandContext = ServerCommandContext(eventLoop: context.eventLoop, db: database)
        let responseFuture = try commandCenter.runCommand(commandName, data: data, context: commandContext)
        responseFuture.whenSuccess { data in
            self._sendResponseJSONData(context: context, data)
        }
        responseFuture.whenFailure { error in
            print("Encountered error running command: \(error)")
            self._sendEmptyStatus(context: context, status: .internalServerError)
        }
    }
    
    private func _sendResponseJSONData(context: ChannelHandlerContext, _ data: Data) {
        var responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: defaultHeaders)
        responseHead.headers.add(name: "Content-Type", value: "application/json; charset=UTF-8")
        self.buffer.clear()
        self.buffer.writeData(data)
        let header = HTTPServerResponsePart.head(responseHead)
        context.write(self.wrapOutboundOut(header), promise: nil)
        let body = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
        context.write(self.wrapOutboundOut(body), promise: nil)
        _completeResponse(context, trailers: nil, promise: nil)
    }
    
    private func _sendEmptyStatus(context: ChannelHandlerContext, status: HTTPResponseStatus) {
        var responseHead = HTTPResponseHead(version: .http1_1, status: .notFound, headers: defaultHeaders)
        self.buffer.clear()
        let message = "\(status.code) \(status.reasonPhrase)"
        self.buffer.writeString(message)
        responseHead.headers.add(name: "Content-Type", value: "text/plain; charset=UTF-8")
        responseHead.headers.add(name: "Content-Length", value: "\(self.buffer!.readableBytes)")
        
        let header = HTTPServerResponsePart.head(responseHead)
        context.write(self.wrapOutboundOut(header), promise: nil)
        let body = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
        context.write(self.wrapOutboundOut(body), promise: nil)
        _completeResponse(context, trailers: nil, promise: nil)
    }
    
    private func _completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        let writeAndFlushPromise: EventLoopPromise<Void> = context.eventLoop.makePromise()
        writeAndFlushPromise.futureResult.cascade(to: promise)
        writeAndFlushPromise.futureResult.whenComplete { _ in
            context.close(promise: nil)
        }
        
        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: writeAndFlushPromise)
    }
}


extension EventLoopPromise where Value == Void {
    func succeed() {
        self.succeed(())
    }
}
