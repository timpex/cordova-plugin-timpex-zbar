//
//  AlmaZBarReaderViewController.m
//  BarCodeMix
//
//  Created by eCompliance on 23/01/15.

#import "AlmaZBarReaderViewController.h"
#import "CsZBar.h"

@interface AlmaZBarReaderViewController ()

@end

@implementation AlmaZBarReaderViewController
@synthesize linearOnly;


- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate{
    return YES;
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation) fromInterfaceOrientation {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    if (self.linearOnly) {
        if(screenWidth >= screenHeight)
            self.scanCrop = CGRectMake(0.0, 0.495, 1.0, 0.01);
        else
            self.scanCrop = CGRectMake(0.495, 0.0, 0.01, 1.0);
    }
    [self.cameraOverlayView setFrame:screenRect];
    [self.cameraOverlayView layoutIfNeeded];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIToolbar* toolbar = [[controls subviews] firstObject];
    if (![toolbar isKindOfClass:UIToolbar.class])
        return;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    // HACK to hide the Info button
    for (UIBarButtonItem* item in [toolbar items]) {
        UIButton* button = [item customView];
        if ([button isKindOfClass:UIButton.class]) {
            UIButtonType buttonType = [button buttonType];
            if (buttonType == UIButtonTypeInfoDark || buttonType == UIButtonTypeInfoLight) {
                [button setHidden:YES];
            }
        }
    }
#endif
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    
    [self.cameraOverlayView setFrame:screenRect];
    [self.cameraOverlayView layoutIfNeeded];
}

@end
