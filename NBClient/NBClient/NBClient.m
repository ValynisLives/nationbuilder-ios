//
//  NBClient.m
//  NBClient
//
//  Created by Peng Wang on 7/8/14.
//  Copyright (c) 2014 NationBuilder. All rights reserved.
//

#import "NBClient.h"
#import "NBClient_Internal.h"

#import "NBAuthenticator.h"
#import "FoundationAdditions.h"
#import "NBPaginationInfo.h"

NSUInteger const NBClientErrorCodeService = 10;
NSString * const NBClientErrorCodeKey = @"code";
NSString * const NBClientErrorHTTPStatusCodeKey = @"NBClientErrorHTTPStatusCode";
NSString * const NBClientErrorMessageKey = @"message";
NSString * const NBClientErrorValidationErrorsKey = @"validation_errors";
NSString * const NBClientErrorInnerErrorKey = @"inner_error";

NSString * const NBClientDefaultAPIVersion = @"v1";
NSString * const NBClientDefaultBaseURLFormat = @"https://%@.nationbuilder.com";

#if DEBUG
static NBLogLevel LogLevel = NBLogLevelDebug;
#else
static NBLogLevel LogLevel = NBLogLevelWarning;
#endif

@implementation NBClient

#pragma mark - Initializers

- (instancetype)initWithNationName:(NSString *)nationName
                     authenticator:(NBAuthenticator *)authenticator
                  customURLSession:(NSURLSession *)urlSession
     customURLSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    self = [super init];
    if (self) {
        [self commonInitWithNationName:nationName customURLSession:urlSession customURLSessionConfiguration:sessionConfiguration];
        self.authenticator = authenticator;
    }
    return self;
}

- (instancetype)initWithNationName:(NSString *)nationName
                            apiKey:(NSString *)apiKey
                     customBaseURL:(NSURL *)baseURL
                  customURLSession:(NSURLSession *)urlSession
     customURLSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    self = [super init];
    if (self) {
        [self commonInitWithNationName:nationName customURLSession:urlSession customURLSessionConfiguration:sessionConfiguration];
        self.apiKey = apiKey;
        self.baseURL = baseURL;
    }
    return self;
}

- (void)commonInitWithNationName:(NSString *)nationName
                customURLSession:(NSURLSession *)urlSession
   customURLSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    self.nationName = nationName;
    self.urlSession = urlSession;
    self.sessionConfiguration = sessionConfiguration;
    
    self.defaultErrorRecoverySuggestion = @"message.unknown-error-solution".nb_localizedString;
}

#pragma mark - NBLogging

+ (void)updateLoggingToLevel:(NBLogLevel)logLevel
{
    LogLevel = logLevel;
}

#pragma mark - Private

#pragma mark Accessors

- (NSURLSessionConfiguration *)sessionConfiguration
{
    static NSURLCache *sharedCache;
    BOOL shouldUseDefaultCache = !_sessionConfiguration || !_sessionConfiguration.URLCache;
    if (shouldUseDefaultCache) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            const NSUInteger mb = 1024 * 1024;
            NSString *desiredApplicationSubdirectoryPath = self.baseURL.host;
            sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * mb
                                                        diskCapacity:20 * mb
                                                            diskPath:desiredApplicationSubdirectoryPath];
        });
    }
    if (!_sessionConfiguration) {
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    if (shouldUseDefaultCache) {
        _sessionConfiguration.URLCache = sharedCache;
    }
    return _sessionConfiguration;
}

- (NSURLSession *)urlSession
{
    if (_urlSession) {
        return _urlSession;
    }
    self.urlSession = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                    delegate:self
                                               delegateQueue:[NSOperationQueue mainQueue]];
    return _urlSession;
}

- (NSString *)apiVersion
{
    if (_apiVersion) {
        return _apiVersion;
    }
    self.apiVersion = NBClientDefaultAPIVersion;
    return _apiVersion;
}

- (void)setApiKey:(NSString *)apiKey
{
    _apiKey = apiKey;
    if (!apiKey) {
        self.baseURLComponents = nil;
    }
}

- (void)setAuthenticator:(NBAuthenticator *)authenticator
{
    _authenticator = authenticator;
    // Did.
    if (authenticator && authenticator.baseURL) {
        self.baseURL = authenticator.baseURL;
    }
}

#pragma mark Requests & Tasks

- (NSURL *)baseURL
{
    if (_baseURL) {
        return _baseURL;
    }
    self.baseURL = [NSURL URLWithString:[NSString stringWithFormat:NBClientDefaultBaseURLFormat, self.nationName]];
    return _baseURL;
}

- (NSURLComponents *)baseURLComponents
{
    if (_baseURLComponents) {
        return _baseURLComponents;
    }
    self.baseURLComponents = [NSURLComponents componentsWithURL:self.baseURL resolvingAgainstBaseURL:YES];
    NSDictionary *queryParameters = @{ @"access_token": self.apiKey ?: @"" };
    _baseURLComponents.path = [NSString stringWithFormat:@"/api/%@", self.apiVersion];
    _baseURLComponents.query = [queryParameters nb_queryStringWithEncoding:NSASCIIStringEncoding
                                               skipPercentEncodingPairKeys:[NSSet setWithObject:@"email"]
                                                charactersToLeaveUnescaped:nil];
    return _baseURLComponents;
}

- (NSMutableURLRequest *)baseFetchRequestWithURL:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                                       timeoutInterval:10.0f];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (self.delegate && [self.delegate respondsToSelector:@selector(client:willCreateDataTaskForRequest:)]) {
        [self.delegate client:self willCreateDataTaskForRequest:request];
    }
    return request;
}

- (NSURLSessionDataTask *)baseFetchTaskWithURLComponents:(NSURLComponents *)components
                                              resultsKey:(NSString *)resultsKey
                                          paginationInfo:(NBPaginationInfo *)paginationInfo
                                       completionHandler:(NBClientResourceListCompletionHandler)completionHandler
{
    if (paginationInfo) {
        NSMutableDictionary *mutableParameters = paginationInfo.dictionary.mutableCopy;
        [mutableParameters removeObjectsForKeys:@[ NBClientNumberOfTotalPagesKey, NBClientNumberOfTotalItemsKey ]];
        [mutableParameters addEntriesFromDictionary:[components.query nb_queryStringParametersWithEncoding:NSASCIIStringEncoding]];
        components.query = [mutableParameters nb_queryStringWithEncoding:NSASCIIStringEncoding
                                             skipPercentEncodingPairKeys:[NSSet setWithObject:@"email"]
                                              charactersToLeaveUnescaped:nil];
    }
    NSMutableURLRequest *request = [self baseFetchRequestWithURL:components.URL];
    NBLogInfo(@"REQUEST: %@", request.nb_debugDescription);
    void (^taskCompletionHandler)(NSData *, NSURLResponse *, NSError *) =
    [self dataTaskCompletionHandlerForFetchResultsKey:resultsKey originalRequest:request completionHandler:^(id results, NSDictionary *jsonObject, NSError *error) {
        NBPaginationInfo *paginationInfo = [[NBPaginationInfo alloc] initWithDictionary:jsonObject];
        if (completionHandler) {
            completionHandler(results, paginationInfo, error);
        }
    }];
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler: taskCompletionHandler];
    return [self startTask:task];
}

- (NSURLSessionDataTask *)baseFetchTaskWithURLComponents:(NSURLComponents *)components
                                              resultsKey:(NSString *)resultsKey
                                       completionHandler:(NBClientResourceItemCompletionHandler)completionHandler
{
    NSMutableURLRequest *request = [self baseFetchRequestWithURL:components.URL];
    NBLogInfo(@"REQUEST: %@", request.nb_debugDescription);
    void (^taskCompletionHandler)(NSData *, NSURLResponse *, NSError *) =
    [self dataTaskCompletionHandlerForFetchResultsKey:resultsKey originalRequest:request completionHandler:^(id results, NSDictionary *jsonObject, NSError *error) {
        if (completionHandler) {
            completionHandler(results, error);
        }
    }];
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:taskCompletionHandler];
    return [self startTask:task];
}

- (NSMutableURLRequest *)baseSaveRequestWithURL:(NSURL *)url
                                     parameters:(NSDictionary *)parameters
                                          error:(NSError *__autoreleasing *)error
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0f];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"PUT"; // Overwrite as needed.
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:parameters options:0 error:error]];
    if (self.delegate && [self.delegate respondsToSelector:@selector(client:willCreateDataTaskForRequest:)]) {
        [self.delegate client:self willCreateDataTaskForRequest:request];
    }
    return request;
}

- (NSURLSessionDataTask *)baseSaveTaskWithURLRequest:(NSURLRequest *)request
                                          resultsKey:(NSString *)resultsKey
                                   completionHandler:(NBClientResourceItemCompletionHandler)completionHandler
{
    NBLogInfo(@"REQUEST: %@", request.nb_debugDescription);
    void (^taskCompletionHandler)(NSData *, NSURLResponse *, NSError *) =
    [self dataTaskCompletionHandlerForFetchResultsKey:resultsKey originalRequest:request completionHandler:^(id results, NSDictionary *jsonObject, NSError *error) {
        if (completionHandler) {
            completionHandler(results, error);
        }
    }];
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:taskCompletionHandler];
    return [self startTask:task];
}

- (NSMutableURLRequest *)baseDeleteRequestWithURL:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0f];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    request.HTTPMethod = @"DELETE";
    if (self.delegate && [self.delegate respondsToSelector:@selector(client:willCreateDataTaskForRequest:)]) {
        [self.delegate client:self willCreateDataTaskForRequest:request];
    }
    return request;
}

- (NSURLSessionDataTask *)baseDeleteTaskWithURL:(NSURL *)url
                              completionHandler:(NBClientResourceItemCompletionHandler)completionHandler
{
    NSURLRequest *request = [self baseDeleteRequestWithURL:url];
    NBLogInfo(@"REQUEST: %@", request.nb_debugDescription);
    void (^taskCompletionHandler)(NSData *, NSURLResponse *, NSError *) =
    [self dataTaskCompletionHandlerForFetchResultsKey:nil originalRequest:request completionHandler:^(id results, NSDictionary *jsonObject, NSError *error) {
        if (completionHandler) {
            completionHandler(results, error);
        }
    }];
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request completionHandler:taskCompletionHandler];
    return [self startTask:task];
}

- (NSURLSessionDataTask *)startTask:(NSURLSessionDataTask *)task
{
    BOOL shouldStart = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(client:shouldAutomaticallyStartDataTask:)]) {
        shouldStart = [self.delegate client:self shouldAutomaticallyStartDataTask:task];
    }
    if (shouldStart) {
        [task resume];
    }
    return task;
}

#pragma mark Handlers

- (void (^)(NSData *, NSURLResponse *, NSError *))dataTaskCompletionHandlerForFetchResultsKey:(NSString *)resultsKey
                                                                              originalRequest:(NSURLRequest *)request
                                                                            completionHandler:(void (^)(id, NSDictionary *, NSError *))completionHandler
{
    return ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        // Bail if delegate wants to handle the whole thing.
        if (self.delegate && [self.delegate respondsToSelector:@selector(client:shouldHandleResponse:forRequest:)]) {
            if (![self.delegate client:self shouldHandleResponse:httpResponse forRequest:request]) {
                return [self logResponse:httpResponse data:data]; // Combined to a one-liner; returns void.
            }
        }
        // Handle data task error.
        if (error) {
            NBLogError(@"%@", error);
            if (self.delegate && [self.delegate respondsToSelector:@selector(client:shouldHandleResponse:forRequest:withDataTaskError:)]) {
                if (![self.delegate client:self shouldHandleResponse:httpResponse forRequest:request withDataTaskError:error]) {
                    return [self logResponse:httpResponse data:data];
                }
            }
            if (completionHandler) { completionHandler(nil, nil, error); }
            return [self logResponse:httpResponse data:data];
        }
        // Handle empty bodies.
        if ([[NSIndexSet nb_indexSetOfSuccessfulEmptyResponseHTTPStatusCodes] containsIndex:httpResponse.statusCode]) {
            if (completionHandler) { completionHandler(nil, nil, error); }
            return [self logResponse:httpResponse data:data];
        }
        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:NSJSONReadingAllowFragments
                                                                     error:&error];
        // Handle HTTP error.
        if (![[NSIndexSet nb_indexSetOfSuccessfulHTTPStatusCodes] containsIndex:httpResponse.statusCode]) {
            error = [self errorForResponse:httpResponse jsonData:jsonObject];
            if (self.delegate && [self.delegate respondsToSelector:@selector(client:shouldHandleResponse:forRequest:withHTTPError:)]) {
                if (![self.delegate client:self shouldHandleResponse:httpResponse forRequest:request withHTTPError:error]) {
                    return [self logResponse:httpResponse data:data];
                }
            }
            NBLogError(@"%@", error);
            if (completionHandler) { completionHandler(nil, nil, error); }
            return [self logResponse:httpResponse data:data];
        }
        // Handle JSON error.
        if (error) {
            NBLogError(@"%@", error);
            if (completionHandler) { completionHandler(nil, nil, error); }
            return [self logResponse:httpResponse data:data];
        }
        // Handle Non-HTTP error or invalid response.
        if (jsonObject[@"code"]) {
            error = [self errorForResponse:httpResponse jsonData:jsonObject];
            if (self.delegate && [self.delegate respondsToSelector:@selector(client:shouldHandleResponse:forRequest:withServiceError:)]) {
                if (![self.delegate client:self shouldHandleResponse:httpResponse forRequest:request withServiceError:error]) {
                    return [self logResponse:httpResponse data:data];
                }
            }
        }
        // Get and check for results.
        if (self.delegate && [self.delegate respondsToSelector:@selector(client:didParseJSON:fromResponse:forRequest:)]) {
            [self.delegate client:self didParseJSON:jsonObject fromResponse:httpResponse forRequest:request];
        }
        id results = jsonObject[resultsKey];
        if (!results) {
            error = [self errorForJsonData:jsonObject resultsKey:resultsKey];
        }
        if (error) {
            NBLogError(@"%@", error);
        }
        // Completed. Successful if error is nil.
        [self logResponse:httpResponse data:jsonObject];
        if (completionHandler) {
            completionHandler(results, jsonObject, error);
        }
    };
}

#pragma mark Helpers

- (NSError *)errorForResponse:(NSHTTPURLResponse *)response
                     jsonData:(NSDictionary *)data
{
    NSString *description;
    if ([[NSIndexSet nb_indexSetOfSuccessfulHTTPStatusCodes] containsIndex:response.statusCode]) {
        description = [NSString localizedStringWithFormat:@"message.nb-error.format".nb_localizedString, data[@"code"]];
    } else {
        description = [NSString localizedStringWithFormat:@"message.nb-http-error.format".nb_localizedString,
                       response.statusCode, data[@"code"]];
    }
    return [NSError
            errorWithDomain:NBErrorDomain
            code:NBClientErrorCodeService
            userInfo:@{ NSLocalizedDescriptionKey: description,
                        NSLocalizedFailureReasonErrorKey: (data[@"message"] ? data[@"message"] : @"message.unknown-error-reason".nb_localizedString),
                        NSLocalizedRecoverySuggestionErrorKey: self.defaultErrorRecoverySuggestion,
                        NBClientErrorCodeKey: (data[NBClientErrorCodeKey] ? data[NBClientErrorCodeKey] : @""),
                        NBClientErrorHTTPStatusCodeKey: @(response.statusCode),
                        NBClientErrorMessageKey: (data[NBClientErrorMessageKey] ? data[NBClientErrorMessageKey] : @""),
                        NBClientErrorValidationErrorsKey: (data[NBClientErrorValidationErrorsKey] ? data[NBClientErrorValidationErrorsKey] : @[]),
                        NBClientErrorInnerErrorKey: (data[NBClientErrorInnerErrorKey] ? data[NBClientErrorInnerErrorKey] : @{}) }];
}

- (NSError *)errorForJsonData:(NSDictionary *)data
                   resultsKey:(NSString *)resultsKey
{
    return [NSError
            errorWithDomain:NBErrorDomain
            code:NBClientErrorCodeService
            userInfo:@{ NSLocalizedDescriptionKey: @"message.invalid-response-data".nb_localizedString,
                        NSLocalizedFailureReasonErrorKey: [NSString localizedStringWithFormat:
                                                           @"message.no-json-results-for-key.format".nb_localizedString,
                                                           resultsKey],
                        NSLocalizedRecoverySuggestionErrorKey: self.defaultErrorRecoverySuggestion }];
}

- (void)logResponse:(NSHTTPURLResponse *)response
               data:(id)data
{
    id body = ([data isKindOfClass:[NSData class]]
               ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
               : data);
    NBLogInfo(@"RESPONSE: %@\n"
              @"BODY: %@",
              response, body);
}

@end
