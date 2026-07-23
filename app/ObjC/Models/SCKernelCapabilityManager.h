#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SCKernelCapabilityCompletion)(BOOL success, NSError * _Nullable error);

@interface SCKernelCapabilityManager : NSObject

@property (nonatomic, copy, readonly, nullable) NSDictionary *report;
@property (nonatomic, copy, readonly) NSString *statusMessage;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;

// Provider + verified kbase/kread. This does not authorize kernel mutation.
@property (nonatomic, readonly) BOOL isKernelRWAvailable;
@property (nonatomic, readonly) BOOL isKernelReadAvailable;
@property (nonatomic, readonly) BOOL isKernelWriteExported;
@property (nonatomic, readonly) BOOL isKernelCallExported;
@property (nonatomic, readonly) BOOL isKernelMutationAvailable;
@property (nonatomic, readonly) BOOL isPrimitiveSelfTestVerified;
@property (nonatomic, copy, readonly) NSString *transactionState;
@property (nonatomic, copy, readonly) NSString *kernelUUID;
@property (nonatomic, copy, readonly) NSString *providerName;
@property (nonatomic, copy, readonly) NSString *realDevice;
@property (nonatomic, copy, readonly) NSString *realOSBuild;
@property (nonatomic, readonly) BOOL isKernelProfileMatched;
@property (nonatomic, copy, readonly) NSString *kernelProfileID;
@property (nonatomic, copy, readonly) NSString *kernelProfileLevel;
@property (nonatomic, copy, readonly) NSString *kernelProviderFamily;

+ (instancetype)shared;
- (void)refreshStatusWithCompletion:(nullable SCKernelCapabilityCompletion)completion;
- (void)runReadOnlyProbeWithCompletion:(nullable SCKernelCapabilityCompletion)completion;
- (void)runPrimitiveSelfTestWithCompletion:(nullable SCKernelCapabilityCompletion)completion;

@end

NS_ASSUME_NONNULL_END
