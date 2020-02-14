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
@synthesize inQrMode;

- (void)updateScanCrop {
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    if(!self.inQrMode) {
        if(screenWidth >= screenHeight)
            self.scanCrop = CGRectMake(0.0, 0.495, 1.0, 0.01);
        else
            self.scanCrop = CGRectMake(0.495, 0.0, 0.01, 1.0);
    } else {
        self.scanCrop = CGRectMake(0.0, 0.0, 1.0, 1.0);
    }
}

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
    CGRect layoutFrame = screenRect;
    [self updateScanCrop];
    
    if (@available(iOS 11, *)) {
        layoutFrame = [[[[UIApplication sharedApplication] keyWindow] safeAreaLayoutGuide] layoutFrame];
    }

    [self.cameraOverlayView setFrame:layoutFrame];
    [self.cameraOverlayView layoutIfNeeded];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGRect layoutFrame = screenRect;
    [self.readerView setFrame:screenRect];
    [self updateScanCrop];
    
    if (@available(iOS 11, *)) {
        layoutFrame = [[[[UIApplication sharedApplication] keyWindow] safeAreaLayoutGuide] layoutFrame];
    }

    [self.cameraOverlayView setFrame:layoutFrame];
    [self.cameraOverlayView layoutIfNeeded];
}

@end
