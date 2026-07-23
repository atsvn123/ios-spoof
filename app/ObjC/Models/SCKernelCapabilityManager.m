#import "SCKernelCapabilityManager.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <string.h>

static NSString * const SCKernelCapabilityErrorDomain = @"com.iosspoof.kernel-capability";

static const NSTimeInterval SCProbeTimeout = 20.0;
static const NSUInteger SCMaxReportBytes = 2 * 1024 * 1024;

static char **SCFilteredEnvironment(void) {
    extern char **environ;
    if (!environ) return NULL;

    int count = 0;
    for (char **p = environ; *p; p++) count++;

    char **filtered = calloc(count + 1, sizeof(char *));
    if (!filtered) return NULL;

    int index = 0;
    for (char **p = environ; *p; p++) {
        if (strncmp(*p, "DYLD_", 5) == 0) continue;
        if (strncmp(*p, "LD_", 3) == 0) continue;
        if (strncmp(*p, "_MSSafeMode", 10) == 0) continue;
        filtered[index] = *p;
        index++;
    }
    filtered[index] = NULL;
    return filtered;
}

static NSString *SCResolvedSafeHelperPath(NSString *path) {
    if (!path.length || ![path hasPrefix:@"/"]) return nil;
    char resolvedPath[PATH_MAX];
    if (!realpath(path.fileSystemRepresentation, resolvedPath)) return nil;
    struct stat info = {0};
    if (stat(resolvedPath, &info) != 0) return nil;
    if (!S_ISREG(info.st_mode)) return nil;
    if (info.st_uid != 0) return nil;
    if (info.st_mode & (S_IWGRP | S_IWOTH)) return nil;
    if (!(info.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH))) return nil;
    return [NSString stringWithUTF8String:resolvedPath];
}

static BOOL SCIsBooleanFalse(id value) {
    return [value isKindOfClass:NSNumber.class] && ![(NSNumber *)value boolValue];
}

@interface SCKernelCapabilityManager ()
@property (nonatomic, copy, readwrite, nullable) NSDictionary *report;
@property (nonatomic, copy, readwrite) NSString *statusMessage;
@property (nonatomic, readwrite, getter=isLoading) BOOL loading;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@end

@implementation SCKernelCapabilityManager

+ (instancetype)shared {
    static SCKernelCapabilityManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [SCKernelCapabilityManager new];
        manager.statusMessage = @"Chưa kiểm tra";
        manager.workQueue = dispatch_queue_create("com.iosspoof.kernel-capability", DISPATCH_QUEUE_SERIAL);
    });
    return manager;
}

- (NSDictionary *)krwReport {
    id value = self.report[@"krw"];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

- (NSDictionary *)kernelProbeReport {
    id value = [self krwReport][@"kernelProbe"];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

- (NSDictionary *)exportsReport {
    id value = [self krwReport][@"exports"];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

- (NSDictionary *)profileReport {
    id value = self.report[@"profileMatch"];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

- (BOOL)reportSatisfiesReadOnlyContract:(NSDictionary *)report {
    if (![report isKindOfClass:NSDictionary.class]) return NO;
    if (![report[@"schemaVersion"] isKindOfClass:NSNumber.class]) return NO;
    if ([report[@"schemaVersion"] integerValue] != 2) return NO;
    if (![report[@"mode"] isEqualToString:@"read-only"]) return NO;

    NSDictionary *safety = report[@"safety"];
    if (![safety isKindOfClass:NSDictionary.class]) return NO;
    NSArray<NSString *> *alwaysFalseKeys = @[
        @"kcallCalled", @"physreadCalled", @"physwriteCalled", @"kernelMutationAllowed", @"artifactHidingEnabled"
    ];
    for (NSString *key in alwaysFalseKeys) {
        if (!SCIsBooleanFalse(safety[key])) return NO;
    }

    NSString *transactionState = report[@"transactionState"];
    BOOL selfTestAttempted = [transactionState isEqualToString:@"selfTestVerified"] ||
        [transactionState isEqualToString:@"selfTestFailed"] ||
        [transactionState isEqualToString:@"quarantined"];
    BOOL vfsTestAttempted = [transactionState isEqualToString:@"vfsTestAttempted"] ||
        [transactionState isEqualToString:@"vfsTestVerified"] ||
        [transactionState isEqualToString:@"vfsTestFailed"];

    NSArray<NSString *> *alwaysFalseKeys = @[
        @"kcallCalled", @"physreadCalled", @"physwriteCalled", @"kernelMutationAllowed", @"artifactHidingEnabled"
    ];
    for (NSString *key in alwaysFalseKeys) {
        if (!SCIsBooleanFalse(safety[key])) return NO;
    }

    if (![safety[@"vnodeMutationCalled"] isKindOfClass:NSNumber.class]) return NO;
    if (!vfsTestAttempted && [safety[@"vnodeMutationCalled"] boolValue]) return NO;

    NSDictionary *environment = report[@"environment"];
    if (![environment isKindOfClass:NSDictionary.class]) return NO;
    id bootTime = environment[@"bootTimeSeconds"];
    if (![bootTime isKindOfClass:NSNumber.class]) return NO;

    NSDictionary *krw = report[@"krw"];
    if (![krw isKindOfClass:NSDictionary.class]) return NO;
    if (![krw[@"libraryPresent"] isKindOfClass:NSNumber.class]) return NO;
    if (![krw[@"kernelProbe"] isKindOfClass:NSDictionary.class]) return NO;
    if (selfTestAttempted && ![krw[@"primitiveSelfTest"] isKindOfClass:NSDictionary.class]) return NO;
    return YES;
}

- (BOOL)isKernelReadAvailable {
    if (![self reportSatisfiesReadOnlyContract:self.report]) return NO;
    return [[self kernelProbeReport][@"machOValidated"] boolValue] &&
        [[self kernelProbeReport][@"kernelReadVerified"] boolValue];
}

- (BOOL)isKernelRWAvailable {
    return [[[self krwReport] objectForKey:@"libraryPresent"] boolValue] && self.isKernelReadAvailable;
}

- (BOOL)isKernelWriteExported {
    return [[self exportsReport][@"kwrite"] boolValue];
}

- (BOOL)isKernelCallExported {
    return [[self exportsReport][@"kcall"] boolValue];
}

- (BOOL)isKernelMutationAvailable {
    return NO;
}

- (BOOL)isPrimitiveSelfTestVerified {
    if (![self reportSatisfiesReadOnlyContract:self.report]) return NO;
    NSDictionary *selfTest = [self krwReport][@"primitiveSelfTest"];
    if (![selfTest isKindOfClass:NSDictionary.class]) return NO;
    NSString *state = [selfTest[@"state"] isKindOfClass:NSString.class] ? selfTest[@"state"] : @"";
    return [state isEqualToString:@"verified"];
}

- (NSString *)transactionState {
    NSString *state = self.report[@"transactionState"];
    return [state isKindOfClass:NSString.class] ? state : @"";
}

- (NSString *)kernelUUID {
    NSString *value = [self kernelProbeReport][@"kernelUUID"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (NSString *)providerName {
    NSArray *images = [self krwReport][@"loadedImages"];
    if (![images isKindOfClass:NSArray.class]) return @"";
    for (NSString *path in images.reverseObjectEnumerator) {
        if ([path isKindOfClass:NSString.class] && [path.lastPathComponent containsString:@"libkrw-"]) {
            return path.lastPathComponent;
        }
    }
    NSString *loadedPath = [self krwReport][@"loadedPath"];
    return [loadedPath isKindOfClass:NSString.class] ? loadedPath.lastPathComponent : @"";
}

- (NSString *)realDevice {
    NSDictionary *environment = self.report[@"environment"];
    NSDictionary *sysctl = [environment isKindOfClass:NSDictionary.class] ? environment[@"sysctl"] : nil;
    NSString *product = [sysctl isKindOfClass:NSDictionary.class] ? sysctl[@"productType"] : nil;
    NSString *board = [sysctl isKindOfClass:NSDictionary.class] ? sysctl[@"hardwareModel"] : nil;
    if (product.length && board.length) return [NSString stringWithFormat:@"%@ / %@", product, board];
    return product.length ? product : @"";
}

- (NSString *)realOSBuild {
    NSDictionary *environment = self.report[@"environment"];
    NSDictionary *sysctl = [environment isKindOfClass:NSDictionary.class] ? environment[@"sysctl"] : nil;
    NSString *build = [sysctl isKindOfClass:NSDictionary.class] ? sysctl[@"osBuild"] : nil;
    return build.length ? build : @"";
}

- (BOOL)isKernelProfileMatched {
    return [[self profileReport][@"matched"] boolValue];
}

- (NSString *)kernelProfileID {
    NSString *value = [self profileReport][@"profileID"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (NSString *)kernelProfileLevel {
    NSString *value = [self profileReport][@"profileLevel"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (NSString *)kernelProviderFamily {
    NSString *value = [self profileReport][@"providerFamily"];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (NSString *)probeExecutablePath {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    char *jbroot = getenv("JBROOT");
    if (jbroot && jbroot[0]) {
        NSString *root = [NSString stringWithUTF8String:jbroot];
        [candidates addObject:[root stringByAppendingString:@"/usr/bin/sckrwprobe"]];
    }
    NSString *appExecutable = NSBundle.mainBundle.executablePath;
    NSString *suffix = @"/Applications/iOSSpoof.app/iOSSpoof";
    if ([appExecutable hasSuffix:suffix]) {
        NSString *root = [appExecutable substringToIndex:appExecutable.length - suffix.length];
        [candidates addObject:[root stringByAppendingString:@"/usr/bin/sckrwprobe"]];
    }
    [candidates addObjectsFromArray:@[
        @"/var/jb/usr/bin/sckrwprobe",
        @"/usr/bin/sckrwprobe"
    ]];

    for (NSString *candidate in candidates) {
        NSString *resolvedCandidate = SCResolvedSafeHelperPath(candidate);
        if (resolvedCandidate.length) return resolvedCandidate;
    }
    return nil;
}

- (void)refreshStatusWithCompletion:(SCKernelCapabilityCompletion)completion {
    [self runProbeArgument:@"--cached" statusMessage:@"Đang tải trạng thái…" completion:completion];
}

- (void)runReadOnlyProbeWithCompletion:(SCKernelCapabilityCompletion)completion {
    [self runProbeArgument:@"--stdout" statusMessage:@"Đang kiểm tra read-only…" completion:completion];
}

- (void)runPrimitiveSelfTestWithCompletion:(SCKernelCapabilityCompletion)completion {
    [self runProbeArgument:@"--selftest" statusMessage:@"Đang chạy primitive self-test…" completion:completion];
}

- (void)runVFSTestWithCompletion:(SCKernelCapabilityCompletion)completion {
    [self runProbeArgument:@"--vfstest" statusMessage:@"Đang chạy VFS test…" completion:completion];
}

- (void)runProbeArgument:(NSString *)argument statusMessage:(NSString *)statusMessage completion:(SCKernelCapabilityCompletion)completion {
    if (self.loading) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"Đang chạy kiểm tra khác"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
        return;
    }

    NSString *executable = [self probeExecutablePath];
    if (!executable.length) {
        NSError *error = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Không tìm thấy sckrwprobe hợp lệ"}];
        self.statusMessage = error.localizedDescription;
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, error); });
        return;
    }

    self.loading = YES;
    self.statusMessage = statusMessage;

    NSString *capturedExecutable = executable;
    NSString *capturedArgument = argument;
    dispatch_async(self.workQueue, ^{
        NSError *resultError = nil;
        NSDictionary *parsedReport = nil;
        int exitCode = -1;

        NSString *temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"sckrwprobe-%@.json", [NSUUID UUID].UUIDString]];
        int outputFD = open(temporaryPath.fileSystemRepresentation, O_CREAT | O_TRUNC | O_WRONLY | O_EXCL, 0600);
        if (outputFD < 0) {
            resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Không thể tạo output tạm cho kernel probe"}];
        } else {
            posix_spawn_file_actions_t actions;
            int actionsInitStatus = posix_spawn_file_actions_init(&actions);
            if (actionsInitStatus != 0) {
                resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:actionsInitStatus userInfo:@{NSLocalizedDescriptionKey: @"posix_spawn_file_actions_init failed"}];
                close(outputFD);
            } else {
                int dupStatus = posix_spawn_file_actions_adddup2(&actions, outputFD, STDOUT_FILENO);
                int closeStatus = posix_spawn_file_actions_addclose(&actions, outputFD);
                if (dupStatus != 0 || closeStatus != 0) {
                    resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:(dupStatus ?: closeStatus) userInfo:@{NSLocalizedDescriptionKey: @"Không thể cấu hình stdout cho sckrwprobe"}];
                    posix_spawn_file_actions_destroy(&actions);
                    close(outputFD);
                } else {
                    const char *path = capturedExecutable.fileSystemRepresentation;
                    char *argv[] = { (char *)path, (char *)capturedArgument.UTF8String, NULL };
                    pid_t child = 0;
                    char **filteredEnvironment = SCFilteredEnvironment();
                    int spawnStatus = posix_spawn(&child, path, &actions, NULL, argv, filteredEnvironment);
                    if (filteredEnvironment) free(filteredEnvironment);
                    posix_spawn_file_actions_destroy(&actions);
                    close(outputFD);

                    if (spawnStatus != 0) {
                        resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:spawnStatus userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Không thể chạy sckrwprobe: %d", spawnStatus]}];
                    } else {
                        struct timespec startTime;
                        clock_gettime(CLOCK_MONOTONIC, &startTime);
                        int waitStatus = 0;
                        BOOL finished = NO;
                        BOOL timedOut = NO;

                        while (YES) {
                            pid_t waitResult = waitpid(child, &waitStatus, WNOHANG);
                            if (waitResult == child) {
                                finished = YES;
                                break;
                            }
                            if (waitResult < 0 && errno != EINTR) break;

                            struct timespec now;
                            clock_gettime(CLOCK_MONOTONIC, &now);
                            double elapsed = (now.tv_sec - startTime.tv_sec) + (now.tv_nsec - startTime.tv_nsec) / 1e9;
                            if (elapsed >= SCProbeTimeout) {
                                timedOut = YES;
                                break;
                            }
                            usleep(100000);
                        }

                        if (timedOut && !finished) {
                            kill(child, SIGTERM);
                            BOOL reaped = NO;
                            for (int attempt = 0; attempt < 25; attempt++) {
                                if (waitpid(child, &waitStatus, WNOHANG) == child) { reaped = YES; break; }
                                usleep(10000);
                            }
                            if (!reaped) {
                                kill(child, SIGKILL);
                                for (int attempt = 0; attempt < 50; attempt++) {
                                    if (waitpid(child, &waitStatus, WNOHANG) == child) { reaped = YES; break; }
                                    usleep(10000);
                                }
                            }
                            resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"Kernel probe quá thời gian 20 giây"}];
                        } else if (finished && WIFEXITED(waitStatus)) {
                            exitCode = WEXITSTATUS(waitStatus);
                        } else if (finished && WIFSIGNALED(waitStatus)) {
                            resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Kernel probe bị kill bởi signal %d", WTERMSIG(waitStatus)]}];
                        } else {
                            resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"Kernel probe kết thúc bất thường"}];
                        }
                    }
                }
            }
        }

        NSData *data = nil;
        struct stat fileStat = {0};
        if (lstat(temporaryPath.fileSystemRepresentation, &fileStat) == 0 &&
            S_ISREG(fileStat.st_mode) && !S_ISLNK(fileStat.st_mode) &&
            fileStat.st_size > 0 && fileStat.st_size <= (off_t)SCMaxReportBytes) {
            data = [NSData dataWithContentsOfFile:temporaryPath options:0 error:nil];
        }
        [NSFileManager.defaultManager removeItemAtPath:temporaryPath error:nil];

        if (!resultError && data.length > 0 && data.length <= SCMaxReportBytes) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&resultError];
            if ([json isKindOfClass:NSDictionary.class]) parsedReport = json;
        }
        if (!resultError && !parsedReport) {
            resultError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:7 userInfo:@{NSLocalizedDescriptionKey: @"Kernel probe không trả về JSON hợp lệ"}];
        }

        NSString *reportedTransactionState = [parsedReport[@"transactionState"] isKindOfClass:NSString.class] ? parsedReport[@"transactionState"] : @"";
        BOOL selfTestProblem = [reportedTransactionState isEqualToString:@"selfTestFailed"] || [reportedTransactionState isEqualToString:@"quarantined"];
        BOOL acceptedExit = (exitCode == 0 || exitCode == 2);
        BOOL validContract = parsedReport && [self reportSatisfiesReadOnlyContract:parsedReport];
        BOOL shouldPublish = acceptedExit && validContract;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (shouldPublish) {
                self.report = parsedReport;
            } else if (parsedReport && !validContract) {
                self.report = nil;
            }

            NSError *finalError = resultError;
            if (parsedReport && !validContract && !finalError) {
                finalError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:8 userInfo:@{NSLocalizedDescriptionKey: @"Báo cáo không đáp ứng read-only safety contract"}];
            }
            if (!acceptedExit && !finalError) {
                finalError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:exitCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Kernel probe trả về exit code %d", exitCode]}];
            }
            if (shouldPublish && selfTestProblem && !finalError) {
                NSString *description = [reportedTransactionState isEqualToString:@"quarantined"] ? @"Primitive self-test bị quarantine" : @"Primitive self-test thất bại";
                finalError = [NSError errorWithDomain:SCKernelCapabilityErrorDomain code:9 userInfo:@{NSLocalizedDescriptionKey: description}];
            }

            self.loading = NO;

            if (shouldPublish && selfTestProblem) {
                self.statusMessage = finalError.localizedDescription ?: @"Primitive self-test thất bại";
            } else if (shouldPublish && self.isKernelReadAvailable) {
                self.statusMessage = @"Kernel read đã xác minh";
            } else if (shouldPublish) {
                self.statusMessage = @"Provider chưa được xác minh";
            } else {
                self.statusMessage = finalError.localizedDescription ?: @"Không có trạng thái";
            }

            BOOL requestSucceeded = shouldPublish && !selfTestProblem;
            if (completion) completion(requestSucceeded, finalError);
        });
    });
}

@end
