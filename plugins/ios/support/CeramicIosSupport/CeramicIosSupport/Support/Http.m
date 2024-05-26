//
//  Http.m
//  CeramicIosSupport
//
//  Created by Jeremy FAIVRE on 27/09/2018.
//  Copyright © 2018 Ceramic. All rights reserved.
//

#import "Http.h"

@implementation Http

#pragma mark - Public API

+ (void)sendHTTPRequest:(NSDictionary *)params done:(void (^)(NSDictionary *response))done {
    
    // Create session configuration
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    // Configure request
    NSMutableURLRequest *request = [[self class] requestWithParams:params];
    
    // Reply flag
    __block BOOL didReply = NO;
    
    // HTTP timeout
    if ([params[@"timeout"] isKindOfClass:[NSNumber class]]) {
        sessionConfig.timeoutIntervalForRequest = (NSTimeInterval) [params[@"timeout"] integerValue];
        sessionConfig.timeoutIntervalForResource = (NSTimeInterval) [params[@"timeout"] integerValue];
        
        // Bulletproof it, whatever happens, we will reply back at last after timout + 1s delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(([params[@"timeout"] intValue] + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (didReply) return;
            didReply = YES;
            
            id statusMessage = [NSHTTPURLResponse localizedStringForStatusCode:408];
            
            // Timeout
            done(@{
               @"status": @(408),
               @"content": [NSNull null],
               @"error": statusMessage ? statusMessage : [NSNull null],
               @"headers": [NSNull null]
            });
        });
    }
    
    // Run request (asynchronously)
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (didReply) return;
        didReply = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSInteger statusCode;
            id statusMessage;
            id content;
            id binaryContent;
            id headers;
            
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                
                // Treat the response as an NSHTTPURLResponse instance
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                
                // Retrieve content type
                __block NSString *contentType = nil;
                [[httpResponse allHeaderFields] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    if ([key isKindOfClass:[NSString class]]) {
                        NSString *keyStr = key;
                        if ([[keyStr lowercaseString] isEqualToString:@"content-type"] && [obj isKindOfClass:[NSString class]]) {
                            contentType = obj;
                            contentType = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                            *stop = YES;
                        }
                    }
                }];
                if (!contentType)
                    contentType = @"application/octet-stream";

                // Status
                statusCode = httpResponse.statusCode;
                statusMessage = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
                
                // Content
                if (data) {
                    if (![self isBinaryMimeType:[contentType lowercaseString]]) {
                        // Text content
                        if ([[contentType lowercaseString] containsString:@"charset=iso-8859-1"]) {
                            // Convert from ISO-8859-1 to UTF-8 if needed
                            content = [[NSString alloc] initWithCString:[[[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] UTF8String] encoding:NSUTF8StringEncoding];
                        }
                        else {
                            content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        }
                        binaryContent = [NSNull null];
                    }
                    else {
                        // Binary content
                        content = [NSNull null];
                        binaryContent = data;
                    }
                }
                if (!content)
                    content = [NSNull null];
                
                
                // Headers
                headers = [httpResponse allHeaderFields];
            }
            else if (error) {
                
                statusCode = [error code] > 0 ? -[error code] : [error code];
                statusMessage = [error localizedDescription];
                content = [NSNull null];
                binaryContent = [NSNull null];
                headers = [NSNull null];
                
            }
            else {
                
                statusCode = 0;
                statusMessage = @"Unknown response";
                content = [NSNull null];
                binaryContent = [NSNull null];
                headers = [NSNull null];
            }
            
            // Reply
            done(@{
                   @"status": @(statusCode),
                   @"content": content,
                   @"binaryContent": binaryContent,
                   @"error": (statusCode >= 400 || statusCode == 0) && statusMessage ? statusMessage : [NSNull null],
                   @"headers": headers ? headers : [NSNull null]
            });
            
        });
        
    }];
    
    [task resume];
    
}

+ (void)download:(NSDictionary *)params targetPath:(NSString *)targetPath done:(void (^)(NSString *fullPath))done {
    
    // Create session configuration
    //NSString *sessionId = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"] stringByAppendingString:@"-ceramic-download"];
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    // We may want to allow download in background later with [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionId];
    
    // Ensure targetPath is an absolute path, if not, prepend library directory path
    NSString *defaultDownloadPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    if (![targetPath hasPrefix:@"/"]) {
        targetPath = [defaultDownloadPath stringByAppendingPathComponent:targetPath];
    }
    
    // Configure request
    NSMutableURLRequest *request = [[self class] requestWithParams:params];
    
    // Reply flag
    __block BOOL didReply = NO;
    
    // HTTP timeout
    if ([params[@"timeout"] isKindOfClass:[NSNumber class]]) {
        sessionConfig.timeoutIntervalForRequest = (NSTimeInterval) [params[@"timeout"] integerValue];
        sessionConfig.timeoutIntervalForResource = (NSTimeInterval) [params[@"timeout"] integerValue];
        
        // Bulletproof it, whatever happens, we will reply back at last after timout + 1s delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(([params[@"timeout"] intValue] + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (didReply) return;
            didReply = YES;
            
            NSLog(@"Error: download timeout");
            
            // Timeout
            done(nil);
        });
    }

    // Run request (asynchronously)
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (didReply) return;
        didReply = YES;
        
        if (error) {
            NSLog(@"Download error: %@", error);
            done(nil);
        }
        else {
            NSString *tmpPath = location.path;
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *targetDir = [targetPath stringByDeletingLastPathComponent];
            
            // Create target directory if needed
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:targetDir isDirectory:&isDir]) {
                if (!isDir) {
                    NSLog(@"Download error: %@ should be a directory", targetDir);
                    done(nil);
                    return;
                }
            }
            else {
                NSError *err = nil;
                [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:nil error:&err];
                if (err) {
                    NSLog(@"Download error: failed to create directory at path: %@", targetDir);
                    done(nil);
                    return;
                }
            }
            
            // Delete existing target file if any
            isDir = NO;
            if ([fm fileExistsAtPath:targetPath isDirectory:&isDir]) {
                if (isDir) {
                    NSLog(@"Download error: cannot overwrite directory: %@", targetPath);
                    done(nil);
                    return;
                }
                NSError *err = nil;
                [fm removeItemAtPath:targetPath error:&err];
                if (err) {
                    NSLog(@"Download error: failed to overwrite file at path: %@", targetPath);
                    done(nil);
                    return;
                }
            }
            
            // Move tmp file to target path
            NSError *err = nil;
            [fm moveItemAtPath:tmpPath toPath:targetPath error:&err];
            if (err) {
                NSLog(@"Download error: failed to move file from %@ to %@", tmpPath, targetPath);
                done(nil);
                return;
            }
            
            // Everything seems fine, finish and provide resulting path
            done(targetPath);
        }
        
    }];
    
    [task resume];
    
}

#pragma mark - Internal

+ (BOOL)isBinaryMimeType:(NSString *)type {
    static NSArray *nonBinaryTypes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nonBinaryTypes = @[
            @"text/html",
            @"text/css",
            @"text/xml",
            @"application/javascript",
            @"application/atom+xml",
            @"application/rss+xml",
            @"text/mathml",
            @"text/plain",
            @"text/vnd.sun.j2me.app-descriptor",
            @"text/vnd.wap.wml",
            @"text/x-component",
            @"image/svg+xml",
            @"application/json",
            @"application/rtf",
            @"application/x-perl",
            @"application/xhtml+xml",
            @"application/xspf+xml"
        ];
    });

    NSRange semicolonRange = [type rangeOfString:@";"];
    if (semicolonRange.location != NSNotFound) {
        type = [type substringToIndex:semicolonRange.location];
    }

    type = [[type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];

    if ([type hasPrefix:@"text/"]) {
        return NO;
    }

    if ([nonBinaryTypes containsObject:type]) {
        return NO;
    }

    return YES;
}

+ (NSMutableURLRequest *)requestWithParams:(NSDictionary *)params {
    
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
        request.timeoutInterval = (NSTimeInterval) [params[@"timeout"] integerValue];
    }
    
    return request;
    
}

@end
