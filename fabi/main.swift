
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
var js = results.map { nsString.substring(with: $0.range).replacingOccurrences(of: "\\n", with: ";;;")}

for i in 0..<results.count {
    nsString = nsString.replacingCharacters(in: results[i].range, with: js[i]) as NSString
}
nsString = nsString.replacingOccurrences(of: "\\n", with: " ") as NSString


let tokens = tokenizer(input: nsString as String)
var parser = Parser(tokens: tokens)
let handlers = try! parser.parseHandler()
var router = Router()
for handler in handlers {
    router.register(handler)
}

let socket = try! Socket()
var server = HTTPServer(socket: socket, handlers: handlers, router: router)
try! server.start()


