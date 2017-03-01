
//  main.swift
//  fabi
//
//  Created by Marcio Klepacz on 1/11/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation

do {
    let args = CommandLine.arguments
    let filePath = args[1]
    var port: in_port_t? = nil
    
    if args[2] == "-p" {
        port = UInt16(args[3])!
    }
    
    var input = try String(contentsOfFile: filePath)
    input = preprocess(input)
    
    let tokens = tokenizer(input: input)
    var parser = Parser(tokens: tokens)
    let handlers = try parser.parseHandler()
    
    var server = try HTTPServer(handlers: handlers)
    if let port = port {
        try server.start(port: port)
    } else {
        try server.start()
    }
    
} catch {
   print("Error: \(error)")
}




