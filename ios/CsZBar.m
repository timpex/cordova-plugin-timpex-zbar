#import "CsZBar.h"
#import <AVFoundation/AVFoundation.h>
#import "AlmaZBarReaderViewController.h"

#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property AlmaZBarReaderViewController *scanReader;
@property (weak, nonatomic) IBOutlet UIView *sightLine;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *switchModeButton;

@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;
@synthesize sightLine;
@synthesize switchModeButton;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command; 
{
    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [AlmaZBarReaderViewController new];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMask(UIInterfaceOrientationPortrait);

        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;

        NSString *flash = [params objectForKey:@"flash"];
        
        if ([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        }

        // Hack to hide the bottom bar's Info button... originally based on http://stackoverflow.com/a/16353530
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 110000
	NSInteger infoButtonIndex;
        if ([[[UIDevice currentDevice] systemVersion] compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
            infoButtonIndex = 1;
        } else {
            infoButtonIndex = 3;
        }
        UIView *infoButton = [[[[[self.scanReader.view.subviews objectAtIndex:2] subviews] objectAtIndex:0] subviews] objectAtIndex:infoButtonIndex];
        [infoButton setHidden:YES];
#endif
        if([params objectForKey:@"linearOnly"] != nil) {
            self.scanReader.inQrMode = ![[params objectForKey:@"linearOnly"] boolValue];
        } else {
            self.scanReader.inQrMode = [self getModeFromUserDefaults];
        }
        
        UIView *overlayView = [[[NSBundle mainBundle] loadNibNamed:@"OverlayView" owner:self options:nil] lastObject];
        [self updateModeButtonTitle];
        
        if(self.scanReader.inQrMode) {
            [sightLine setBackgroundColor:[UIColor clearColor]];
        } else {
            [sightLine setBackgroundColor:[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.75f]];
        }
        
        self.scanReader.showsZBarControls = NO;
        self.scanReader.showsCameraControls = NO;
        self.scanReader.cameraOverlayView = overlayView;
        
        [self.viewController presentViewController:self.scanReader animated:YES completion:nil];
    }
}

- (void)toggleflash {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if (device.torchAvailable == 1) {
        if (device.torchMode == 0) {
            [device setTorchMode:AVCaptureTorchModeOn];
            [device setFlashMode:AVCaptureFlashModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
            [device setFlashMode:AVCaptureFlashModeOff];
        }
    }
    
    [device unlockForConfiguration];
}

#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

- (void)updateModeButtonTitle {
    if(self.scanReader.inQrMode)
        [switchModeButton setTitle:@"Switch to Linear"];
    else
        [switchModeButton setTitle:@"Switch to Mixed"];
}

- (BOOL)getModeFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:@"timpex-zbar-inQrMode"]) {
        return [defaults boolForKey:@"timpex-zbar-inQrMode"];
    }
    return YES;
}

- (void)setMode:(BOOL)inQrMode {
    self.scanReader.inQrMode = inQrMode;
    if(!self.scanReader.inQrMode) {
        [sightLine setBackgroundColor:[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.75f]];
        [switchModeButton setTitle:@"Switch to Mixed"];
    } else {
        [sightLine setBackgroundColor:[UIColor clearColor]];
        [switchModeButton setTitle:@"Switch to Linear"];
    }
    [self.scanReader updateScanCrop];
    
    // Remember choice for later
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.scanReader.inQrMode forKey:@"timpex-zbar-inQrMode"];
    [defaults synchronize];
}

#pragma mark - Button callbacks

- (IBAction)toggleFlashPressed:(id)sender {
    [self toggleflash];
}

- (IBAction)cancelPressed:(id)sender {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_ERROR
                               messageAsString: @"cancelled"]];
    }];
}
- (IBAction)switchModePressed:(id)sender {
    [self setMode:!self.scanReader.inQrMode];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }
    
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    
    ZBarSymbol *symbol = nil;
    for (symbol in results) break; // get the first result
    
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_OK
                                messageAsString: symbol.data]];
    }];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"Failed"]];
    }];
}

@end
