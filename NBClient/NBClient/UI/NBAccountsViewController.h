//
//  NBAccountsViewController.h
//  NBClient
//
//  Copyright (c) 2014-2015 NationBuilder. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NBAccountsViewDefines.h"
#import "NBDefines.h"

@class NBAccountButton;

@interface NBAccountsViewController : UIViewController <NBLogging>

@property (nonatomic, weak) id<NBAccountsViewDataSource> dataSource;

@property (nonatomic, weak, readonly) UIImageView *avatarImageView;
@property (nonatomic, weak, readonly) UILabel *nameLabel;
@property (nonatomic, weak, readonly) UILabel *nationLabel;
@property (nonatomic, weak, readonly) UIView *accountView;

@property (nonatomic, weak, readonly) UIButton *signOutButton;
@property (nonatomic, weak, readonly) UIButton *addAccountButton;

@property (nonatomic, weak, readonly) UIPickerView *accountsPicker;

@property (nonatomic, weak, readonly) UIImageView *logoImageView;

@property (nonatomic) UIColor *borderColor UI_APPEARANCE_SELECTOR;
@property (nonatomic) NSNumber *cornerRadius UI_APPEARANCE_SELECTOR;

@property (nonatomic) UIColor *buttonBackgroundColor UI_APPEARANCE_SELECTOR;

@property (nonatomic) UIColor *imageBorderColor UI_APPEARANCE_SELECTOR;
@property (nonatomic) NSNumber *imageCornerRadius UI_APPEARANCE_SELECTOR;

@property (nonatomic) NSNumber *appearanceDuration UI_APPEARANCE_SELECTOR;

@property (nonatomic, getter = isPresentedInPopover) BOOL presentedInPopover;
@property (nonatomic) BOOL shouldAutoPromptForNationSlug;

// You can call this manually if you decide to turn off auto-prompting.
- (void)promptForNationSlug;

// This is a convenience method for showing the accounts view controller. Using
// this means being able to use the custom override of -dismissViewControllerAnimate:completion:.
// You may use it if you wish, but know that it's technically outside of the
// account view controller's responsibility to know how to present itself, and
// that your code should contain the presentation logic.
- (void)showWithAccountButton:(NBAccountButton *)accountButton
     presentingViewController:(UIViewController *)presentingViewController;

@end
