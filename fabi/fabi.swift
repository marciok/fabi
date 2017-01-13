//
//  fabi.swift
//  fabi
//
//  Created by Marcio Klepacz on 1/11/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation
import JavaScriptCore

/// Shamessly copied from: https://github.com/matthewcheok/Kaleidoscope/blob/238c1942163e251d3f74bcae67531085f29ecda9/Kaleidoscope/Regex.swift
var expressions = [String: NSRegularExpression]()

public extension String {
    public func match(regex: String, line: Bool = true) -> String? {
        let expression: NSRegularExpression
        if let exists = expressions[regex] {
            expression = exists
        } else {
            expression = try! NSRegularExpression(pattern: "^\(regex)", options: [])
            expressions[regex] = expression
        }
        
        let range = expression.rangeOfFirstMatch(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        if range.location != NSNotFound {
            return (self as NSString).substring(with: range)
        }
        
        return nil
    }
}

enum Token {
    case method(HTTPMethod)
    case path(String)
    case body(String)
}

enum HTTPMethod: String {
    case GET
    case POST
}

typealias TokenGenerator = (String) -> Token?

func tokenizer(input: String) -> [Token] {
    let tokensGenerator: [(String, TokenGenerator)] = [
        ("[A-Z][A-Z]*", {
            guard $0 == HTTPMethod.GET.rawValue || $0 == HTTPMethod.POST.rawValue else {
                return nil
            }
            
            return Token.method(HTTPMethod(rawValue: $0)!)
        }),        
        //TODO: I suck at regex. Refactor the code an exclude characters using regular expression.
        ("\\/(.*?)\\&", {
            return .path(String($0.characters.dropLast().dropLast()))
        }),
        ("\\;;;(.*?)\\@@", {
            
            print($0)
            let bodyContent = String($0.characters.dropLast().dropLast())
            
            return .body(bodyContent)
        }),
        ("#.*", { _ in nil })
    ]
    
    var tokens = [Token]()
    var content = input
    
    while content.characters.count > 0 {
        var matched = false
        
        for (pattern, generator) in tokensGenerator {
            if let match = content.match(regex: pattern) {
                
                if let token = generator(match) {
                    tokens.append(token)
                }
                content = content.substring(from: content.characters.index(content.startIndex, offsetBy: match.characters.count))
                matched = true
                break
            }
        }
        
        if !matched {
            let index = content.characters.index(content.startIndex, offsetBy: 1)
            content = content.substring(from: index)
        }
    }
    
    return tokens
}


/*
 handler: httpMethod route body
 httpMethod: get
 route: path
 body: body
 */

struct Request {
    let method: HTTPMethod
    let path: [String]
}

struct Handler {
    let request: Request
    let response: String
}

public enum ParsingError: Error {
    case invalidTokens(expecting: String)
    case incompleteExpression
}

struct Parser {
    
    let tokens: [Token]
    var index = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    private func peekCurrentToken() throws -> Token {
        
        if index < tokens.count {
            return tokens[index]
        }
        
        throw ParsingError.incompleteExpression
    }
    
    private mutating func popCurrentToken() throws -> Token {
        let token = tokens[index]
        index += 1
        
        return token
    }
    
    private mutating func parseRoute() throws -> [String]  {
        guard case let .path(content) = try popCurrentToken() else {
            throw ParsingError.invalidTokens(expecting: "Expecting path")
        }
        
        return content.characters.split(separator: "/").map(String.init)
    }
    
    private mutating func parseBody() throws -> String {
        guard case let .body(content) = try popCurrentToken() else {
            throw ParsingError.invalidTokens(expecting: "Expecting body")
        }
        
        return content
    }
    
    mutating func parseHandler() throws -> [Handler]  {
        var nodes = [Handler]()
        while index < tokens.count {
            guard case let .method(httpMethod) = try popCurrentToken() else {
                throw ParsingError.invalidTokens(expecting: "Expecting HTTP method")
            }
            let route = try parseRoute()//TODO Rename
            let body  = try parseBody()
            let request = Request(method: httpMethod, path: route)
            let handler = Handler(request: request, response: body)
            
            nodes.append(handler)
            
        }
        
        return nodes
    }
}

final class Node {
    var nodes: [String: Node] = [:]
    var handler: String? = nil
}

struct Router {
//    var handlers = Set<Handler>() TODO
    var nodes = [String: Node]()
    
    private var rootNode = Node()
    
    mutating func register(_ handler: Handler) {
        var route = handler.request.path
        route.insert(handler.request.method.rawValue, at: 0)
        var routeIterator = route.makeIterator()
        
        inflate(&rootNode, generator: &routeIterator).handler = handler.response
    }
    
    private func inflate(_ node: inout Node, generator: inout IndexingIterator<[String]>) -> Node {
        if let pathSegment = generator.next() {
            if let _ = node.nodes[pathSegment] {
                return inflate(&node.nodes[pathSegment]!, generator: &generator)
            }
            var nextNode = Node()
            node.nodes[pathSegment] = nextNode
            return inflate(&nextNode, generator: &generator)
        }
        return node
    }
    
    private func findHandler(_ node: inout Node, params: inout [String: String], generator: inout IndexingIterator<[String]>) -> String? {
        guard let pathToken = generator.next() else {
            // if it's the last element of the requested URL, check if there is a pattern with variable tail.
            if let variableNode = node.nodes.filter({ $0.0.characters.first == ":" }).first {
                if variableNode.value.nodes.isEmpty {
                    params[variableNode.0] = ""
                    
                    return variableNode.value.handler
                }
            }
            return node.handler
        }
        let variableNodes = node.nodes.filter { $0.0.characters.first == ":" }
        if let variableNode = variableNodes.first {
            if variableNode.1.nodes.count == 0 {
                // if it's the last element of the pattern and it's a variable, stop the search and
                // append a tail as a value for the variable.
                let tail = generator.joined(separator: "/")
                if tail.characters.count > 0 {
                    params[variableNode.0] = pathToken + "/" + tail
                } else {
                    params[variableNode.0] = pathToken
                }
                return variableNode.1.handler
            }
            params[variableNode.0] = pathToken
            return findHandler(&node.nodes[variableNode.0]!, params: &params, generator: &generator)
        }
        if var node = node.nodes[pathToken] {
            return findHandler(&node, params: &params, generator: &generator)
        }
        return nil
    }
    
    public mutating func route(_ request: Request) -> ([String: String], String)? {
        var route = request.path
        route.insert(request.method.rawValue, at: 0)
        let pathSegments = route
        var pathSegmentsGenerator = pathSegments.makeIterator()
        var params = [String: String]()
        
        if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
            return (params, handler)
        }

        return nil
    }
}


//MARK: Web Server

typealias SocketDescriptor = Int32

enum SocketError: Error {
    case failed(String)
}

func errnoDescription() -> String {
    return String(cString: UnsafePointer(strerror(errno)))
}

struct Socket {
    let descriptor: SocketDescriptor
    
    init() throws {
        descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        var value: Int32 = 1
        if setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            Darwin.close(descriptor) // TODO: Refactor
            throw SocketError.failed(errnoDescription())
        }

    }
    
    init(descriptor: SocketDescriptor) {
        self.descriptor = descriptor
    }
    
    static let CarriageReturn = UInt8(13)
    static let NewLine = UInt8(10)
    
    func bindAndListen(port: in_port_t = 8080) throws {
        
        if descriptor == -1 {
            throw SocketError.failed(errnoDescription())
        }
        
        var address = sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
            sin_family: UInt8(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr(s_addr: in_addr_t(0)),
            sin_zero:(0, 0, 0, 0, 0, 0, 0, 0))
        
        var bindResult: Int32 = -1
        bindResult = withUnsafePointer(to: &address) {
            bind(descriptor, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        
        if bindResult == -1 {
            throw SocketError.failed(errnoDescription())
        }
        
        if listen(descriptor, SOMAXCONN) == -1 {
            throw SocketError.failed(errnoDescription())
        }
    }
    
    func acceptClient() throws -> Socket {
        var addr = sockaddr()
        var len: socklen_t = 0
        let clientSocket = accept(descriptor, &addr, &len)
        if clientSocket == -1 {
            throw SocketError.failed(errnoDescription())
        }
        
        return Socket(descriptor: clientSocket)
    }
    
    func readLine() throws -> String {
        var characters = ""
        var n: UInt8 = 0
        repeat {
            n = try read()
            if n > Socket.CarriageReturn {
                characters.append(Character(UnicodeScalar(n)))
            }
        } while n != Socket.NewLine
        
        return characters
    }
    
    func read() throws -> UInt8 {
        var buffer = [UInt8](repeatElement(0, count: 1))
        let next = recv(descriptor, &buffer, Int(buffer.count), 0)
        if next <= 0 {
            throw SocketError.failed(errnoDescription())
        }
        
        return buffer[0]
    }
    
    func write(message: String) throws -> String {
        let data = ArraySlice(message.utf8)
       
        try data.withUnsafeBufferPointer {
            var sent = 0
            let length = data.count
            while sent < length {
                let s = Darwin.write(descriptor, $0.baseAddress! + sent, Int(length - sent))
                if s <= 0 {
                    throw SocketError.failed("could send")
                }
                sent += s
            }
        }
        
        return message
    }
    
    func writeOK() throws -> String {
        return try write(message: "HTTP/1.1 200 OK\r\n")
    }
    
    func write404() throws -> String {
        return try write(message: "HTTP/1.1 404 Not Found\r\n")
    }
    
    func close() throws {
        guard Darwin.close(descriptor) == 0 else {
            throw SocketError.failed(errnoDescription())
        }
    }
    
}

struct HTTPServer {
    let socket: Socket
    let handlers: [Handler]
    var router: Router
    
    mutating func start(port: in_port_t = 8080) throws {
        try socket.bindAndListen()
        print("Server started at \(port)")
        
        while let client = try? socket.acceptClient() {
            let response = try client.readLine()
            let statusLineTokens = response.characters.split { $0 == " " }.map(String.init)
            if statusLineTokens.count < 3 {
                throw SocketError.failed(errnoDescription())
            }
            
            print("Recieved: \(response)")
            
            let path = statusLineTokens[1].characters.split(separator: "/").map(String.init)
            guard let httpMethod = HTTPMethod.init(rawValue: statusLineTokens[0]) else {
                _ = try client.write404()
                try client.close()
                
                continue
            }
            
            let request = Request(method: httpMethod, path: path)
            guard let (params, content) = router.route(request) else { //TODO take care of the params
                _ = try client.write404()
                try client.close()
                
                continue
            }
            
            let paramsDeclaration = params.keys.map{ String($0.characters.dropFirst()) }.joined(separator: ",")
            
            let jsSource = "var mainFunc = function(\(paramsDeclaration)) { \(content) }"
            let context = JSContext()
            context?.evaluateScript(jsSource)
            
            let mainFunc = context?.objectForKeyedSubscript("mainFunc")
            let result = mainFunc!.call(withArguments: Array(params.values))
            let evaluated =  String(describing: result!)
            
            print(evaluated)
            let data = [UInt8](evaluated.utf8)
            
            _ = try client.writeOK()
            _ = try client.write(message: "Content-Length: \(data.count)\r\n")
            _ = try client.write(message: "Content-Type: text/html\r\n")
            _ = try client.write(message: "\r\n")
            print(try client.write(message: evaluated))
            
            try client.close()
        }
    }
}






