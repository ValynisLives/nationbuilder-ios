//
//  NBClient_Internal.h
//  NBClient
//
//  Copyright (c) 2014-2015 NationBuilder. All rights reserved.
//

#import "NBClient.h"

@interface NBClient ()

@property (nonatomic, copy, readwrite) NSString *nationSlug;
@property (nonatomic, readwrite) NSURLSession *urlSession;
@property (nonatomic, readwrite) NSURLSessionConfiguration *sessionConfiguration;

@property (nonatomic, readwrite) NBAuthenticator *authenticator;

@property (nonatomic, readwrite) NSURL *baseURL;
@property (nonatomic) NSURLComponents *baseURLComponents;
@property (nonatomic, copy) NSString *defaultErrorRecoverySuggestion;

- (void)commonInitWithNationSlug:(NSString *)nationSlug
                customURLSession:(NSURLSession *)urlSession
   customURLSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration;

// These request methods are called by default in the base*TaskWithURL: methods,
// but you can call them to customize the request for the endpoint and pass the
// request into base*TaskForURLRequest:
- (NSMutableURLRequest *)baseFetchRequestWithURL:(NSURL *)url;
- (NSURLSessionDataTask *)baseFetchTaskWithURLComponents:(NSURLComponents *)components
                                              resultsKey:(NSString *)resultsKey
                                          paginationInfo:(NBPaginationInfo *)paginationInfo
                                       completionHandler:(NBClientResourceListCompletionHandler)completionHandler;
- (NSURLSessionDataTask *)baseFetchTaskWithURLComponents:(NSURLComponents *)components
                                              resultsKey:(NSString *)resultsKey
                                       completionHandler:(NBClientResourceItemCompletionHandler)completionHandler;

- (NSMutableURLRequest *)baseSaveRequestWithURL:(NSURL *)url
                                     parameters:(NSDictionary *)parameters
                                          error:(NSError **)error;
// This is the more common save method.
-(NSURLSessionDataTask *)baseSaveTaskWithURL:(NSURL *)url
                                  parameters:(NSDictionary *)parameters
                                  resultsKey:(NSString *)resultsKey
                           completionHandler:(NBClientResourceItemCompletionHandler)completionHandler;
// And its alternate is the common create method.
-(NSURLSessionDataTask *)baseCreateTaskWithURL:(NSURL *)url
                                    parameters:(NSDictionary *)parameters
                                    resultsKey:(NSString *)resultsKey
                             completionHandler:(NBClientResourceItemCompletionHandler)completionHandler;
// This is the less common one, for custom requests.
// NOTE: We use a dynamically typed block (to allow both resource item and list
//       completion handlers) because there's no other different in method selector
//       if it were to be two methods, unlike the base fetch task methods.
- (NSURLSessionDataTask *)baseSaveTaskWithURLRequest:(NSURLRequest *)request
                                          resultsKey:(NSString *)resultsKey
                                   completionHandler:(id)completionHandler;

- (NSMutableURLRequest *)baseDeleteRequestWithURL:(NSURL *)url;
// This is the more common delete method.
- (NSURLSessionDataTask *)baseDeleteTaskWithURL:(NSURL *)url
                              completionHandler:(NBClientResourceItemCompletionHandler)completionHandler;
// This is the less common one, for custom requests.
- (NSURLSessionDataTask *)baseDeleteTaskWithURLRequest:(NSURLRequest *)request
                                     completionHandler:(NBClientResourceItemCompletionHandler)completionHandler;

- (NSURLSessionDataTask *)startTask:(NSURLSessionDataTask *)task;

- (void (^)(NSData *, NSURLResponse *, NSError *))dataTaskCompletionHandlerForFetchResultsKey:(NSString *)resultsKey
                                                                              originalRequest:(NSURLRequest *)request
                                                                            completionHandler:(void (^)(id results, NSDictionary *jsonObject, NSError *error))completionHandler;

- (NSError *)errorForResponse:(NSHTTPURLResponse *)response jsonData:(NSDictionary *)data;
- (NSError *)errorForJsonData:(NSDictionary *)data resultsKey:(NSString *)resultsKey;
- (void)logResponse:(NSHTTPURLResponse *)response data:(id)data;

@end
