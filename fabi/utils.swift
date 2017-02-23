//
//  utils.swift
//  fabi
//
//  Created by Marcio Klepacz on 1/13/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation

extension NSRange {
    func range(for str: String) -> Range<String.Index>? {
        guard location != NSNotFound else { return nil }
        
        guard let fromUTFIndex = str.utf16.index(str.utf16.startIndex, offsetBy: location, limitedBy: str.utf16.endIndex) else { return nil }
        guard let toUTFIndex = str.utf16.index(fromUTFIndex, offsetBy: length, limitedBy: str.utf16.endIndex) else { return nil }
        guard let fromIndex = String.Index(fromUTFIndex, within: str) else { return nil }
        guard let toIndex = String.Index(toUTFIndex, within: str) else { return nil }
        
        return fromIndex ..< toIndex
    }
}

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
