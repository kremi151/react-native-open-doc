
#import "RNCOpenDoc.h"
#if __has_include("NSTiffSplitter.h")
#import "NSTiffSplitter.h"
#endif
#if __has_include("RCTConvert.h")
#import "RCTConvert.h"
#else
#import <React/RCTConvert.h>
#endif
#import <MobileCoreServices/UTCoreTypes.h>

@interface RNCOpenDoc ()

@property (retain, nonatomic) UIDocumentInteractionController* documentInteractionController;

@end

@implementation RNCOpenDoc {
    RCTResponseSenderBlock pickCallback;
    NSMutableArray *pickResponse;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(open: (NSURL *)path resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        NSString *relPath = path.relativePath;
#if __has_include("NSTiffSplitter.h")
        if ([relPath hasSuffix:@".tif"] || [relPath hasSuffix:@".tiff"]){
            NSTiffSplitter* tiffSplitter = [[NSTiffSplitter alloc] initWithImageUrl:path usingMapping:YES];
            if (tiffSplitter.countOfImages > 1) {
                [self openWith:path];
                return;
            }
        }
#endif
        self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:path];
        self.documentInteractionController.delegate = self;
        BOOL fileOpenSuccess = [self.documentInteractionController presentPreviewAnimated:YES];
        if (!fileOpenSuccess) {
            [self openWith:path];
        }
    } @finally {
        resolve(@true);
    }
}

- (void) openWith:(NSURL *)path
{
    self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:path];
    self.documentInteractionController.delegate = self;

    UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    CGRect screenRect = [[root view] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    BOOL fileOpenSuccess = [self.documentInteractionController
                            presentOptionsMenuFromRect:CGRectMake((screenWidth / 2), screenHeight, 1, 1)
                            inView:[root view] animated:YES];

    if (!fileOpenSuccess) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No suitable Apps installed"
                                                        message:@"You don't seem to have any other Apps installed that can open this document."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

RCT_EXPORT_METHOD(pick:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    NSArray *allowedUTIs = @[(NSString*)kUTTypeContent];
    if (options) {
        allowedUTIs = [RCTConvert NSArray:options[@"fileTypes"]];
    }
    UIDocumentPickerViewController *docPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:allowedUTIs inMode:UIDocumentPickerModeImport];

    //Set the delegate
    docPicker.delegate = self;
    //present the document picker
    UIViewController *rootViewController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];

    pickCallback = callback;

    [rootViewController presentViewController:docPicker animated:YES completion:nil];
}

- (void)getResultFromUrl:(NSURL *)url error:(NSError **)outError {
    [url startAccessingSecurityScopedResource];

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];

    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:outError byAccessor:^(NSURL *newURL) {
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        [result setValue:newURL.absoluteString forKey:@"uri"];
        [result setValue:[newURL lastPathComponent] forKey:@"fileName"];
        [pickResponse addObject:result];
    }];

    [url stopAccessingSecurityScopedResource];
}


#pragma mark -
#pragma mark Document Interaction Controller Delegate Methods

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller
{
    return [[[[UIApplication sharedApplication] delegate] window] rootViewController];
}

#pragma mark -
#pragma mark UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        pickResponse = [NSMutableArray arrayWithCapacity:1];
         __block NSError *error;
        [self getResultFromUrl:url error:&error];
        if (error) {
            pickCallback(@[[error localizedDescription], pickResponse]);
        }
        else {
            pickCallback(@[[NSNull null], pickResponse]);
        }
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray <NSURL *>*)urls {
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        pickResponse = [NSMutableArray arrayWithCapacity:urls.count];
        __block NSError *error;
        for (NSURL *url in urls) {
            [self getResultFromUrl:url error:&error];
            if (error) {
                break;
            }
        }

        if (error) {
            pickCallback(@[[error localizedDescription], pickResponse]);
        }
        else {
            pickCallback(@[[NSNull null], pickResponse]);
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    pickCallback(@[[NSNull null], [NSNull null]]);
}


@end
  
