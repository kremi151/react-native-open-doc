
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

RCT_EXPORT_METHOD(openWith: (NSURL *)path resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self openWith:path];
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

// Determine MIME type: Taken from https://stackoverflow.com/a/32389490/5339584
- (NSString*) determineMimeType: (NSString *) path {
    // NSURL will read the entire file and may exceed available memory if the file is large enough. Therefore, we will write the first fiew bytes of the file to a head-stub for NSURL to get the MIMEType from.
    NSFileHandle *readFileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *fileHead = [readFileHandle readDataOfLength:100]; // we probably only need 2 bytes. we'll get the first 100 instead.

    NSString *tempPath = [NSHomeDirectory() stringByAppendingPathComponent: @"tmp/fileHead.tmp"];

    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil]; // delete any existing version of fileHead.tmp
    if ([fileHead writeToFile:tempPath atomically:YES])
    {
        NSURL* fileUrl = [NSURL fileURLWithPath:path];
        NSURLRequest* fileUrlRequest = [[NSURLRequest alloc] initWithURL:fileUrl cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:.1];

        NSError* error = nil;
        NSURLResponse* response = nil;
        [NSURLConnection sendSynchronousRequest:fileUrlRequest returningResponse:&response error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
        return [response MIMEType];
    }
    return nil;
}

- (void)getResultFromUrl:(NSURL *)url error:(NSError **)outError {
    [url startAccessingSecurityScopedResource];

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];

    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:outError byAccessor:^(NSURL *newURL) {
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        [result setValue:newURL.absoluteString forKey:@"uri"];
        [result setValue:[newURL lastPathComponent] forKey:@"fileName"];

        NSError *attributesError = nil;
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:newURL.path error:&attributesError];
        if(!attributesError) {
            [result setValue:[fileAttributes objectForKey:NSFileSize] forKey:@"fileSize"];
        }
        [result setValue:[self determineMimeType:newURL.path] forKey:@"mimeType"];

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
  
