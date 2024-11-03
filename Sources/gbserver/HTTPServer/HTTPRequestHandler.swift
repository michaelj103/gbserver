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

final class HTTPRequestHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var buffer: ByteBuffer!
    private var defaultHeaders: HTTPHeaders!
    
    // current request state
    private var requestHeader: HTTPRequestHead?
    private var hasProcessed = false
    
    private let database: DatabaseManager
    private let commandCenter: ServerJSONCommandCenter
    init(_ db: DatabaseManager, commandCenter: ServerJSONCommandCenter) {
        database = db
        self.commandCenter = commandCenter
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
        guard let urlComponents = URLComponents(string: requestHeader.uri) else {
            print("Unable to parse as URL \(requestHeader.uri)")
            _sendEmptyStatus(context: context, status: .internalServerError)
            return
        }
        hasProcessed = true
        
        let apiPrefix = "/api/"
        let relativePath = urlComponents.path
        if !relativePath.hasPrefix(apiPrefix) {
            _sendEmptyStatus(context: context, status: .notFound)
        } else {
            let commandString = String(relativePath.dropFirst(apiPrefix.count))
            
            let processingType: RequestProcessingType
            switch requestHeader.method {
            case .GET:
                processingType = .get(urlComponents.queryItems ?? [])
            case .POST:
                let bodyData: Data = requestBody != nil ? Data(buffer: requestBody!, byteTransferStrategy: .noCopy) : "{}".data(using: .utf8)!
                processingType = .post(bodyData)
            default:
                processingType = .unsupported
            }
            
            do {
                try _runCommand(context: context, commandName: commandString, processingType: processingType)
            } catch ServerJSONCommandError.unrecognizedCommand {
                print("Unrecognized command \"\(commandString)\"")
                _sendEmptyStatus(context: context, status: .badRequest)
            } catch ServerJSONCommandError.decodeError(let underlyingError) {
                print("Command decode error \(underlyingError)")
                _sendEmptyStatus(context: context, status: .badRequest)
            } catch RequestError.commandError(let message) {
                print("Immediate request error: \(message ?? "")")
                _sendMessageStatus(context: context, status: .badRequest, customMessage: message)
            } catch {
                // Not sure what could have gone wrong at this layer. Command should know (and have already logged)
                print("Command-specific error occurred for \"\(commandString)\": \(error)")
                _sendEmptyStatus(context: context, status: .internalServerError)
            }
        }
    }
    
    private func _runCommand(context: ChannelHandlerContext, commandName: String, processingType: RequestProcessingType) throws {
        let commandContext = ServerCommandContext(eventLoop: context.eventLoop, db: database)
        
        let responseFuture: EventLoopFuture<Data>
        switch processingType {
        case .get(let query):
            responseFuture = try commandCenter.runCommand(commandName, query: query, context: commandContext)
        case .post(let data):
            responseFuture = try commandCenter.runCommand(commandName, data: data, context: commandContext)
        case .unsupported:
            responseFuture = context.eventLoop.makeFailedFuture(RequestError.unsupportedHTTPMethod)
        }
        
        responseFuture.whenSuccess { data in
            self._sendResponseJSONData(context: context, data)
        }
        responseFuture.whenFailure { error in
            print("Command \"\(commandName)\" encountered an error: \(error)")
            if let requestError = error as? RequestError {
                if case .commandError(let message) = requestError {
                    self._sendMessageStatus(context: context, status: .badRequest, customMessage: message)
                } else {
                    self._sendEmptyStatus(context: context, status: .badRequest)
                }
            } else if ((error as? ServerJSONCommandError) != nil) {
                self._sendEmptyStatus(context: context, status: .badRequest)
            }
            else {
                self._sendEmptyStatus(context: context, status: .internalServerError)
            }
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
        var responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: defaultHeaders)
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
    
    private func _sendMessageStatus(context: ChannelHandlerContext, status: HTTPResponseStatus, customMessage: String?) {
        var responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: defaultHeaders)
        self.buffer.clear()
        let message = "\(status.code) \(status.reasonPhrase)"
        self.buffer.writeString(message)
        if let customMessage = customMessage {
            buffer.writeString("\n\(customMessage)")
        }
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
    
    private enum RequestProcessingType {
        case get([URLQueryItem])
        case post(Data)
        case unsupported
    }
    
    enum RequestError: Error {
        case unsupportedHTTPMethod
        case commandError(String?)
    }
}


extension EventLoopPromise where Value == Void {
    func succeed() {
        self.succeed(())
    }
}
