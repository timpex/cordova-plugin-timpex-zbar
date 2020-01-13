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
@property (weak, nonatomic) IBOutlet UIBarButtonItem *flashButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property NSArray<NSNumber*> *allowedLengths;
@property NSArray<NSString*> *barcodeMayContain;
@property (weak, nonatomic) IBOutlet UIView *colorOverlay;
@property bool multiscan;
@property (weak, nonatomic) IBOutlet UILabel *labelItem3;
@property (weak, nonatomic) IBOutlet UILabel *labelItem2;
@property (weak, nonatomic) IBOutlet UILabel *labelItem1;
@property (weak, nonatomic) IBOutlet UIView *toastContainer;
@property (weak, nonatomic) IBOutlet UILabel *toastLabel;
@property NSMutableArray<NSString*> *scannedValues;
@property (weak, nonatomic) IBOutlet UILabel *countLabel;
@end

#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;
@synthesize sightLine;
@synthesize switchModeButton;
@synthesize flashButton;
@synthesize doneButton;
@synthesize allowedLengths;
@synthesize barcodeMayContain;
@synthesize colorOverlay;
@synthesize multiscan;
@synthesize labelItem3;
@synthesize labelItem2;
@synthesize labelItem1;
@synthesize toastContainer;
@synthesize toastLabel;
@synthesize scannedValues;
@synthesize countLabel;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
    [self initDoneButton];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Plugin API

- (void)addValidItem: (CDVInvokedUrlCommand*)command; {
    NSString *value = (NSString*) [command argumentAtIndex:0];
    [self handleLabel2AndLabel3];
    [labelItem1 setText:value];
    [labelItem1 setTextColor:UIColor.whiteColor];
    [self incrementValidCount];
}

- (void)addInvalidItem: (CDVInvokedUrlCommand*)command; {
    NSString *value = (NSString*) [command argumentAtIndex:0];
    [self handleLabel2AndLabel3];
    [labelItem1 setText:value];
    [labelItem1 setTextColor:UIColor.redColor];
}

- (void)handleLabel2AndLabel3 {
    [labelItem3 setText:labelItem2.text];
    [labelItem3 setTextColor:labelItem2.textColor];
    [labelItem2 setText:labelItem1.text];
    [labelItem2 setTextColor:labelItem1.textColor];
}

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
        self.scannedValues = [NSMutableArray array];
        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        
        self.multiscan = [params objectForKey:@"multiscan"];
        self.allowedLengths = [params objectForKey:@"allowed_lengths"];
        self.barcodeMayContain = [params objectForKey:@"barcode_may_contain"];
        NSString *flash = [params objectForKey:@"flash"];
        
        if ([flash isEqualToString:@"on"]) {
            [self setTorchMode:AVCaptureTorchModeOn];
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([flash isEqualToString:@"off"]) {
            [self setTorchMode:AVCaptureTorchModeOff];
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }else if ([flash isEqualToString:@"auto"]) {
            [self setTorchMode:AVCaptureTorchModeAuto];
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
        if (device.torchMode == AVCaptureTorchModeOn) {
            [device setTorchMode:AVCaptureTorchModeOff];
        } else {
            [device setTorchMode:AVCaptureTorchModeOn];
        }
    }
    [self updateFlashButton];
    [device unlockForConfiguration];
}

#pragma mark - Helpers
- (void)initDoneButton {
    if (@available(iOS 13.0, *)) {
        [doneButton setImage:[UIImage systemImageNamed:@"xmark"]];
    } else {
        [doneButton setImage:[UIImage imageNamed:@"xmark"]];
    }
}
- (void)fadeIn: (UIView*)view completion:(void(^)(BOOL))onComplete {
    [UIView animateWithDuration:0.2f animations:^{
        [view setAlpha:.8f];
    } completion:onComplete];
}

- (void)fadeOut: (UIView*)view completion:(void(^)(BOOL))onComplete delay:(NSTimeInterval)ms {
    [UIView animateWithDuration:0.2f
                          delay:ms
                        options:UIViewAnimationOptionTransitionCrossDissolve
                     animations:^{
                            [view setAlpha:0];
                        }
                     completion:onComplete];
}

- (void)flash: (UIView*)view completion:(void(^)(BOOL))onComplete delay:(NSTimeInterval)ms {
    [self fadeIn:view completion:^(BOOL finished) {
        [self fadeOut:view completion:onComplete delay:ms];
    }];
}

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

- (void)updateModeButtonTitle {
    if(self.scanReader.inQrMode) {
        if (@available(iOS 13.0, *)) {
            [switchModeButton setImage:[UIImage systemImageNamed:@"qrcode"]];
        } else {
            [switchModeButton setImage:[UIImage imageNamed:@"qrcode"]];
        }
    }
    else {
        if (@available(iOS 13.0, *)) {
            [switchModeButton setImage:[UIImage systemImageNamed:@"barcode"]];
        } else {
            [switchModeButton setImage:[UIImage imageNamed:@"barcode"]];
        }
    }
}

- (void)updateFlashButton {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(device.torchMode == AVCaptureTorchModeOn) {
        if (@available(iOS 13.0, *)) {
            [flashButton setImage:[UIImage systemImageNamed:@"bolt.fill"]];
        } else {
            [flashButton setImage:[UIImage imageNamed:@"bolt"]];
        }
    }
    else if(device.torchMode == AVCaptureTorchModeOff){
        if (@available(iOS 13.0, *)) {
            [flashButton setImage:[UIImage systemImageNamed:@"bolt.slash.fill"]];
        } else {
            [flashButton setImage:[UIImage imageNamed:@"bolt.slash"]];
        }
    }
    else if(device.torchMode == AVCaptureTorchModeAuto){
        if (@available(iOS 13.0, *)) {
            [flashButton setImage:[UIImage systemImageNamed:@"bolt.a.fill"]];
        } else {
            [flashButton setImage:[UIImage imageNamed:@"bolt.a"]];
        }
    }
}

- (BOOL)getModeFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if([[[defaults dictionaryRepresentation] allKeys] containsObject:@"timpex-zbar-inQrMode"]) {
        return [defaults boolForKey:@"timpex-zbar-inQrMode"];
    }
    return YES;
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    [device setTorchMode:torchMode];
    [self updateFlashButton];
    [device unlockForConfiguration];
}

- (void)setMode:(BOOL)inQrMode {
    self.scanReader.inQrMode = inQrMode;
    [self updateModeButtonTitle];
    if(!self.scanReader.inQrMode) {
        [sightLine setBackgroundColor:[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.75f]];
        
    } else {
        [sightLine setBackgroundColor:[UIColor clearColor]];
    }
    [self.scanReader updateScanCrop];
    
    // Remember choice for later
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.scanReader.inQrMode forKey:@"timpex-zbar-inQrMode"];
    [defaults synchronize];
}

- (void)showToast:(NSString*)toastMsg {
    [toastLabel setText:toastMsg];
    [self flash:self->toastContainer
     completion:nil
          delay:2
     ];
}

- (void)hideToast {
    [toastContainer setAlpha:0.0f];
}

- (void)incrementValidCount {
    int currentCount = countLabel.text.intValue;
    currentCount += 1;
    [countLabel setText: [@(currentCount) stringValue]];
}

#pragma mark - Button callbacks

- (IBAction)toggleFlashPressed:(id)sender {
    [self toggleflash];
}

- (IBAction)donePressed:(id)sender {
     [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
           self.scanInProgress = NO;
           [self sendScanResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_NO_RESULT]];
       }];
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
    BOOL isValid = NO;
    BOOL isAlreadyScanned = NO;
    for (symbol in results) {
        if([scannedValues indexOfObject:symbol.data] != NSNotFound) {
            isAlreadyScanned = YES;
        } else if ([self isValidBarcode:symbol.data]) {
            isValid = YES;
            isAlreadyScanned = NO;
            break;
        }
    } // get the first result
    if(!isValid && !isAlreadyScanned) {
        [self showToast:@"QR/Barcode is not valid"];
        return;
    }
    
    if(isAlreadyScanned) {
        [self showToast:@"QR/Barcode has already been scanned!"];
        return;
    }
    
    [self hideToast];
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsString: symbol.data];
    if(self.multiscan) {
        [result setKeepCallbackAsBool:YES];
        [self sendScanResult: result];
        [self flash:self->colorOverlay completion:nil delay:0.0f];
        [scannedValues addObject:symbol.data];
        
    } else {
        [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
            self.scanInProgress = NO;
            [result setKeepCallbackAsBool:NO];
            [self sendScanResult: result];
        }];
    }
}

- (BOOL) isValidBarcode:(NSString*)barcodeCandidate {
    return [self barcodeIsOfLength:barcodeCandidate] || [self barcodeContainsSubstring:barcodeCandidate];
}

- (BOOL) barcodeIsOfLength:(NSString*)candidate {
    if(self.allowedLengths == nil) return YES;
    if([self.allowedLengths count] == 0) return YES;

    for (NSNumber *length in self.allowedLengths) {
        if([length intValue] == [candidate length])
            return YES;
    }
    return NO;
}

- (BOOL) barcodeContainsSubstring:(NSString*)candidate {
    if(self.barcodeMayContain == nil) return YES;
	if([self.barcodeMayContain count] == 0) return YES;    

    for (NSString *contains in self.barcodeMayContain) {
        NSRange range = [candidate rangeOfString:contains];
        if(range.location != NSNotFound)
            return YES;
    }
    return NO;
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
