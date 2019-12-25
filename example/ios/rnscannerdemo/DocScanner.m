#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>

@interface RCT_EXTERN_MODULE(DocScanner, NSObject)

RCT_EXTERN_METHOD(startScan:(NSString) options resolver:(RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

@end
