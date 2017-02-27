//
//  TestJS.h
//  fabi
//
//  Created by Marcio Klepacz on 2/27/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavascriptCore.h>

@protocol JSMethodsBridge <JSExport>

+ (NSString *)render:(id)html;

@end


