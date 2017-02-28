
//  main.swift
//  fabi
//
//  Created by Marcio Klepacz on 1/11/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation

do {
    var input = try String(contentsOfFile: "/Users/MarcioK/Projects/fabi/fabi/hello.fab")
    input = preprocess(input)
    
    let tokens = tokenizer(input: input)
    var parser = Parser(tokens: tokens)
    let handlers = try parser.parseHandler()
    
    var router = Router()
    
    for handler in handlers {
        router.register(handler)
    }
    
    var runtime = JSRuntime()
    runtime["bubulu"] = Bubulu.self
    let socket = try Socket()
    
    var server = HTTPServer(socket: socket,
                            router: router,
                            handlers: handlers,
                            runtime: runtime) // TODO: Fix that
    try server.start()
    
} catch {
   print("Error: \(error)")
}




