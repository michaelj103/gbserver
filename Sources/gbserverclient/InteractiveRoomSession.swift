//
//  InteractiveRoomSession.swift
//  
//
//  Created by Michael Brandt on 8/15/22.
//

import Foundation
import GBLinkServerProtocol

class InteractiveRoomSession {
    let connection: LinkClientConnection
    private let sessionID: UUID
    private let inputQueue: DispatchQueue
    private let outputQueue: DispatchQueue
    
    init(connection: LinkClientConnection) {
        self.connection = connection
        self.sessionID = UUID()
        self.inputQueue = DispatchQueue(label: "InputQueue")
        self.outputQueue = DispatchQueue(label: "OutputQueue")
    }
    
    private static var persistentSessions = [UUID:InteractiveRoomSession]()
    func keepAlive() {
        InteractiveRoomSession.persistentSessions[sessionID] = self
    }
    
    func stopKeepAlive() {
        InteractiveRoomSession.persistentSessions.removeValue(forKey: sessionID)
    }
    
    func start() {
        connection.setMessageCallback { [weak self] message in
            self?._handleOutput(message)
        }
        
        _listenForInput()
    }
    
    private func _listenForInput() {
        inputQueue.async {
            while let inputString = readLine() {
                self._parseInput(inputString)
            }
            self.connection.close()
        }
    }
    
    private func _parseInput(_ line: String) {
        if line == "exit" {
            connection.close()
        } else {
            let splits = line.split(separator: " ")
            guard splits.count == 2 else {
                outputQueue.async {
                    print("Unrecognized command")
                }
                return
            }
            
            guard let byte = UInt8(splits[1]) else {
                outputQueue.async {
                    print("Bad argument")
                }
                return
            }
            
            switch splits[0].lowercased() {
            case "init":
                connection.write([LinkServerCommand.initialByte.rawValue] + [byte])
            case "push":
                connection.write([LinkServerCommand.pushByte.rawValue] + [byte])
            case "present":
                connection.write([LinkServerCommand.presentByte.rawValue] + [byte])
            default:
                outputQueue.async {
                    print("Unrecognized command")
                }
            }
        }
    }
    
    private func _handleOutput(_ message: LinkClientMessage) {
        outputQueue.async {
            switch message {
            case .didConnect:
                print("Received didConnect message")
            case .bytePushed(let byte):
                print("Received pushed byte \(byte)")
            case .pullByte(let byte):
                print("Received pulled byte \(byte)")
            case .pullByteStale(let byte):
                print("Received stale pulled byte \(byte)")
            case .commitStaleByte:
                print("Commit stale byte")
            }
        }
    }
    
}
