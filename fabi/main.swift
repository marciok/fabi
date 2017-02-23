
//  main.swift
//  fabi
//
//  Created by Marcio Klepacz on 1/11/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation


var input = try! String(contentsOfFile: "/Users/MarcioK/Projects/fabi/fabi/hello.fab")
input = input.replacingOccurrences(of: "\n", with: "\\n")
let regex = try! NSRegularExpression(pattern: "\\&\\\\n(.*?)\\@@")
var nsString = input as NSString
let results = regex.matches(in: input, range: NSRange(location: 0, length: nsString.length))
var js = results.map { nsString.substring(with: $0.range).replacingOccurrences(of: "\\n", with: ";;")}
input = nsString as String
for i in 0..<results.count {
    input = input.replacingCharacters(in: results[i].range.range(for: input)!, with: js[i])
}

input = input.replacingOccurrences(of: "\\n", with: " ")


let tokens = tokenizer(input: input)
var parser = Parser(tokens: tokens)
let handlers = try! parser.parseHandler()
var router = Router()
for handler in handlers {
    router.register(handler)
}

let socket = try! Socket()
var server = HTTPServer(socket: socket, router: router, handlers: handlers) // TODO: Fix that
try! server.start()


