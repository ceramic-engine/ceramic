//
//  Http.m
//  CeramicIosSupport
//
//  Created by Jeremy FAIVRE on 27/09/2018.
//  Copyright © 2018 Ceramic. All rights reserved.
//

#import "Http.h"

@implementation Http

+ (void)sendHTTPRequest:(NSDictionary *)params done:(void (^)(NSDictionary *response))done {
    
    // Create request
    NSURL *url = [NSURL URLWithString:params[@"url"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // HTTP method
    if ([params[@"method"] isKindOfClass:[NSString class]]) {
        request.HTTPMethod = params[@"method"];
    }
    
    // HTTP body
    if ([params[@"content"] isKindOfClass:[NSString class]]) {
        request.HTTPBody = [params[@"content"] dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // HTTP headers
    if ([params[@"headers"] isKindOfClass:[NSDictionary class]]) {
        [params[@"headers"] enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
            [request addValue:obj forHTTPHeaderField:key];
        }];
    }
    
    // HTTP timeout
    if ([params[@"timeout"] isKindOfClass:[NSNumber class]]) {
        request.timeoutInterval = [params[@"timeout"] floatValue];
    }
    
    // Run request (asynchronously)
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSInteger statusCode;
            id statusMessage;
            id content;
            id headers;
            
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                
                // Treat the response as an NSHTTPURLResponse instance
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                
                // Status
                statusCode = httpResponse.statusCode;
                statusMessage = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
                
                // Content
                content = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : [NSNull null];
                
                // Headers
                headers = [httpResponse allHeaderFields];
            }
            else if (error) {
                
                statusCode = [error code] > 0 ? -[error code] : [error code];
                statusMessage = [error localizedDescription];
                content = [NSNull null];
                headers = [NSNull null];
                
            }
            else {
                
                statusCode = 0;
                statusMessage = @"Unknown response";
                content = [NSNull null];
                headers = [NSNull null];
            }
            
            // Reply
            done(@{
                   @"status": @(statusCode),
                   @"content": content,
                   @"error": statusCode >= 400 && statusMessage ? statusMessage : [NSNull null],
                   @"headers": headers ? headers : [NSNull null]
            });
            
        });
        
    }] resume];
    
} //sendHTTPRequest

@end
