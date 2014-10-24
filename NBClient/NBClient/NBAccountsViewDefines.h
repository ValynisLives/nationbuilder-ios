//
//  NBAccountsViewDefines.h
//  NBClient
//
//  Created by Peng Wang on 10/9/14.
//  Copyright (c) 2014 NationBuilder. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NBAccount;
@class NBAccountsManager;

@protocol NBAccountViewDataSource;

@protocol NBAccountsManagerDelegate <NSObject>

- (void)accountsManager:(NBAccountsManager *)accountsManager failedToSwitchToAccount:(NBAccount *)account withError:(NSError *)error;

@optional

- (void)accountsManager:(NBAccountsManager *)accountsManager willAddAccount:(NBAccount *)account;
- (void)accountsManager:(NBAccountsManager *)accountsManager willSwitchToAccount:(NBAccount *)account;
- (void)accountsManager:(NBAccountsManager *)accountsManager didSwitchToAccount:(NBAccount *)account;

@end

@protocol NBAccountsViewDataSource <NSObject>

@property (nonatomic, strong, readonly) NSArray *accounts;
@property (nonatomic, strong) id<NBAccountViewDataSource> selectedAccount;

@property (nonatomic, readonly, getter = isSignedIn) BOOL signedIn;

- (BOOL)addAccountWithNationSlug:(NSString *)nationSlug error:(NSError **)error;
- (BOOL)signOutWithError:(NSError **)error;

@end

@protocol NBAccountViewDataSource <NSObject>

@property (nonatomic, strong, readonly) NSString *name; // `username`, otherwise `full_name`
@property (nonatomic, strong, readonly) NSString *nationSlug;
@property (nonatomic, strong) NSData *avatarImageData; // Set to nil to clear memory.

@end

@protocol NBAccountsViewDelegate <NSObject>

@end