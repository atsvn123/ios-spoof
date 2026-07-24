#import <Foundation/Foundation.h>

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <mach/machine.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/fcntl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <uuid/uuid.h>

#ifndef VISSHADOW
#define VISSHADOW 0x008000
#endif

// All struct offsets (p_pid, p_list.le_next, v_flag, p_fd, fd_ofiles,
// f_fglob, fg_data) are discovered dynamically by scanning kernel memory
// layouts at runtime. No hardcoded offsets.

typedef int (*SCKBaseFunction)(uint64_t *address);
typedef int (*SCKReadFunction)(uint64_t address, void *buffer, size_t length);
typedef int (*SCKWriteFunction)(void *from, uint64_t to, size_t length);
typedef int (*SCKMallocFunction)(uint64_t *addr, size_t size);
typedef int (*SCKDeallocFunction)(uint64_t addr, size_t size);
typedef uint64_t (*SCKCallFunction)(uint64_t func, uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

static NSString * const SCProbeVersion = @"2";
static NSString * const SCReportPath = @"/var/root/Library/Logs/iOSSpoof/sckrwprobe.json";
static NSString * const SCOffsetCachePath = @"/var/root/Library/Logs/iOSSpoof/vfs_offsets.json";
static const uint32_t SCMaxLoadCommands = 4096;
static const uint32_t SCMaxLoadCommandBytes = 4 * 1024 * 1024;
enum { SCMaxKernelRanges = 64 };
static const uint32_t SCMaxPid = 99999;
static const uint32_t SCOffsetCacheVersion = 2;

static NSString *SCStatusString(int status) {
    if (status == 0) return @"success";
    if (status > 0 && status < 256) {
        const char *description = strerror(status);
        if (description) {
            return [NSString stringWithFormat:@"%d (%s)", status, description];
        }
    }
    return [NSString stringWithFormat:@"%d", status];
}

static NSString *SCHexAddress(uint64_t address) {
    return [NSString stringWithFormat:@"0x%016llx", (unsigned long long)address];
}

static uint64_t SCParseHexAddress(NSString *str) {
    if (!str.length) return 0;
    const char *s = str.UTF8String;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
    return strtoull(s, NULL, 16);
}

static BOOL SCMachNameEquals(const char field[16], const char *expected) {
    size_t length = strlen(expected);
    if (length > 16 || memcmp(field, expected, length) != 0) return NO;
    return length == 16 || field[length] == '\0';
}

static NSString *SCUUIDString(const uuid_t uuid) {
    NSUUID *value = [[NSUUID alloc] initWithUUIDBytes:uuid];
    return value.UUIDString;
}

static NSString *SCSysctlString(const char *name) {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0 || size > 1024 * 1024) return nil;

    void *buffer = calloc(1, size + 1);
    if (!buffer) return nil;

    NSString *value = nil;
    if (sysctlbyname(name, buffer, &size, NULL, 0) == 0) {
        ((char *)buffer)[size] = '\0';
        value = [NSString stringWithUTF8String:buffer];
    }
    free(buffer);
    return value;
}

static NSDictionary *SCRealEnvironment(void) {
    struct utsname info = {0};
    NSMutableDictionary *environment = [NSMutableDictionary dictionary];

    if (uname(&info) == 0) {
        environment[@"uname"] = @{
            @"sysname": [NSString stringWithUTF8String:info.sysname] ?: @"",
            @"nodename": [NSString stringWithUTF8String:info.nodename] ?: @"",
            @"release": [NSString stringWithUTF8String:info.release] ?: @"",
            @"version": [NSString stringWithUTF8String:info.version] ?: @"",
            @"machine": [NSString stringWithUTF8String:info.machine] ?: @""
        };
    }

    NSMutableDictionary *sysctl = [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSString *> *keys = @{
        @"hw.machine": @"productType",
        @"hw.model": @"hardwareModel",
        @"kern.osversion": @"osBuild",
        @"kern.ostype": @"osType",
        @"kern.osrelease": @"osRelease",
        @"kern.version": @"kernelVersion"
    };
    [keys enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *reportKey, BOOL *stop) {
        NSString *value = SCSysctlString(key.UTF8String);
        if (value.length) sysctl[reportKey] = value;
    }];
    environment[@"sysctl"] = sysctl;
    environment[@"uid"] = @(getuid());
    environment[@"effectiveUid"] = @(geteuid());

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *layout = @"unknown";
    if ([fileManager fileExistsAtPath:@"/var/jb"]) {
        layout = @"rootless";
    } else if ([fileManager fileExistsAtPath:@"/.installed_palera1n"] ||
               [fileManager fileExistsAtPath:@"/.bootstrapped"] ||
               [fileManager fileExistsAtPath:@"/Applications/Cydia.app"]) {
        layout = @"rootful";
    }
    environment[@"bootstrapLayout"] = layout;

    size_t boottimeSize = sizeof(struct timeval);
    struct timeval boottime = {0};
    if (sysctlbyname("kern.boottime", &boottime, &boottimeSize, NULL, 0) == 0 && boottime.tv_sec > 0) {
        environment[@"bootTimeSeconds"] = @(boottime.tv_sec);
    }
    return environment;
}

static NSString *SCJbrootPrefix(void) {
    char *jbroot = getenv("JBROOT");
    if (jbroot && jbroot[0]) return [NSString stringWithUTF8String:jbroot];
    NSString *executable = NSProcessInfo.processInfo.arguments.firstObject;
    NSString *suffix = @"/usr/bin/sckrwprobe";
    if ([executable hasSuffix:suffix]) {
        return [executable substringToIndex:executable.length - suffix.length];
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:@"/var/jb"]) return @"/var/jb";
    return @"";
}

static NSString *SCResolvedSafeLibraryPath(NSString *path) {
    if (!path.length || ![path hasPrefix:@"/"]) return nil;
    char resolvedPath[PATH_MAX];
    if (!realpath(path.fileSystemRepresentation, resolvedPath)) return nil;
    struct stat info = {0};
    if (stat(resolvedPath, &info) != 0) return nil;
    if (!S_ISREG(info.st_mode)) return nil;
    if (info.st_uid != 0) return nil;
    if (info.st_mode & (S_IWGRP | S_IWOTH)) return nil;
    return [NSString stringWithUTF8String:resolvedPath];
}

static NSArray<NSString *> *SCKRWLibraryCandidates(void) {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *jbroot = SCJbrootPrefix();
    if (jbroot.length) {
        [candidates addObject:[jbroot stringByAppendingString:@"/usr/lib/libkrw.0.dylib"]];
        [candidates addObject:[jbroot stringByAppendingString:@"/usr/lib/libkrw.dylib"]];
    }
    [candidates addObjectsFromArray:@[
        @"/usr/lib/libkrw.0.dylib",
        @"/usr/lib/libkrw.dylib"
    ]];
    return candidates;
}

static void *SCOpenKRWLibrary(NSString **loadedPath, NSMutableArray<NSDictionary *> *attempts) {
    for (NSString *candidate in SCKRWLibraryCandidates()) {
        NSMutableDictionary *attempt = [NSMutableDictionary dictionary];
        attempt[@"path"] = candidate;
        NSString *resolvedCandidate = SCResolvedSafeLibraryPath(candidate);
        if (!resolvedCandidate.length) {
            attempt[@"opened"] = @NO;
            attempt[@"error"] = @"rejected: not a root-owned regular file or writable by group/others";
            [attempts addObject:attempt];
            continue;
        }
        attempt[@"resolvedPath"] = resolvedCandidate;
        dlerror();
        void *handle = dlopen(resolvedCandidate.UTF8String, RTLD_NOW | RTLD_LOCAL);
        const char *error = dlerror();
        attempt[@"opened"] = @(handle != NULL);
        attempt[@"error"] = error ? [NSString stringWithUTF8String:error] : @"";
        [attempts addObject:attempt];
        if (handle) {
            if (loadedPath) *loadedPath = resolvedCandidate;
            return handle;
        }
    }
    return NULL;
}

static NSArray<NSString *> *SCLoadedKRWImages(void) {
    NSMutableArray<NSString *> *images = [NSMutableArray array];
    uint32_t count = _dyld_image_count();
    for (uint32_t index = 0; index < count; index++) {
        const char *name = _dyld_get_image_name(index);
        if (!name) continue;
        NSString *path = [NSString stringWithUTF8String:name];
        if ([path.lowercaseString containsString:@"libkrw"] && ![images containsObject:path]) {
            [images addObject:path];
        }
    }
    return images;
}

static NSDictionary *SCExportReport(void *handle) {
    NSArray<NSString *> *symbols = @[
        @"kbase", @"kread", @"kwrite", @"kcall",
        @"kmalloc", @"kdealloc", @"physread", @"physwrite"
    ];
    NSMutableDictionary *exports = [NSMutableDictionary dictionary];
    for (NSString *symbol in symbols) {
        exports[symbol] = @(dlsym(handle, symbol.UTF8String) != NULL);
    }
    return exports;
}

static BOOL SCValidateKernelAddress(uint64_t address) {
    return address >= 0xffff000000000000ULL && (address & 0xfffULL) == 0;
}

static NSDictionary *SCProbeKernel(SCKBaseFunction kbaseFunction, SCKReadFunction kreadFunction) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    uint64_t kernelBase = 0;
    int baseStatus = kbaseFunction(&kernelBase);
    result[@"kbaseStatus"] = SCStatusString(baseStatus);
    result[@"kernelBaseVerified"] = @NO;
    result[@"kernelReadVerified"] = @NO;
    result[@"machOValidated"] = @NO;

    if (baseStatus != 0) return result;

    result[@"kernelBase"] = SCHexAddress(kernelBase);
    if (!SCValidateKernelAddress(kernelBase)) {
        result[@"error"] = @"kbase returned a non-canonical or unaligned kernel address";
        return result;
    }

    struct mach_header_64 firstHeader = {0};
    struct mach_header_64 secondHeader = {0};
    int firstReadStatus = kreadFunction(kernelBase, &firstHeader, sizeof(firstHeader));
    int secondReadStatus = firstReadStatus == 0
        ? kreadFunction(kernelBase, &secondHeader, sizeof(secondHeader))
        : firstReadStatus;
    result[@"firstHeaderReadStatus"] = SCStatusString(firstReadStatus);
    result[@"secondHeaderReadStatus"] = SCStatusString(secondReadStatus);

    if (firstReadStatus != 0 || secondReadStatus != 0) {
        result[@"error"] = @"kread could not read the kernel Mach-O header twice";
        return result;
    }
    if (memcmp(&firstHeader, &secondHeader, sizeof(firstHeader)) != 0) {
        result[@"error"] = @"kernel Mach-O header changed between repeated reads";
        return result;
    }

    result[@"kernelReadVerified"] = @YES;
    result[@"machHeader"] = @{
        @"magic": [NSString stringWithFormat:@"0x%08x", firstHeader.magic],
        @"cpuType": @(firstHeader.cputype),
        @"cpuSubtype": @(firstHeader.cpusubtype),
        @"fileType": @(firstHeader.filetype),
        @"commandCount": @(firstHeader.ncmds),
        @"commandBytes": @(firstHeader.sizeofcmds),
        @"flags": [NSString stringWithFormat:@"0x%08x", firstHeader.flags]
    };

    if (firstHeader.magic != MH_MAGIC_64 ||
        firstHeader.cputype != CPU_TYPE_ARM64 ||
        firstHeader.filetype != MH_EXECUTE ||
        firstHeader.ncmds == 0 ||
        firstHeader.ncmds > SCMaxLoadCommands ||
        firstHeader.sizeofcmds < sizeof(struct load_command) ||
        firstHeader.sizeofcmds > SCMaxLoadCommandBytes) {
        result[@"error"] = @"kernel Mach-O header failed validation";
        return result;
    }

    result[@"kernelBaseVerified"] = @YES;
    NSMutableData *commands = [NSMutableData dataWithLength:firstHeader.sizeofcmds];
    uint64_t commandsAddress = kernelBase + sizeof(struct mach_header_64);
    if (commandsAddress < kernelBase || commands.length > UINT64_MAX - commandsAddress) {
        result[@"error"] = @"kernel load-command address overflow";
        return result;
    }

    int commandsStatus = kreadFunction(commandsAddress, commands.mutableBytes, commands.length);
    result[@"loadCommandsReadStatus"] = SCStatusString(commandsStatus);
    if (commandsStatus != 0) {
        result[@"error"] = @"kread could not read kernel load commands";
        return result;
    }

    const uint8_t *bytes = commands.bytes;
    NSUInteger offset = 0;
    NSString *kernelUUID = nil;
    BOOL foundUUID = NO;
    for (uint32_t index = 0; index < firstHeader.ncmds; index++) {
        if (offset > commands.length || commands.length - offset < sizeof(struct load_command)) {
            result[@"error"] = @"truncated kernel load command";
            return result;
        }

        const struct load_command *command = (const struct load_command *)(bytes + offset);
        if (command->cmdsize < sizeof(struct load_command) ||
            (command->cmdsize % 8) != 0 ||
            command->cmdsize > commands.length - offset) {
            result[@"error"] = @"invalid kernel load-command size";
            return result;
        }

        if (command->cmd == LC_UUID) {
            if (foundUUID || command->cmdsize < sizeof(struct uuid_command)) {
                result[@"error"] = @"invalid LC_UUID command";
                return result;
            }
            const struct uuid_command *uuidCommand = (const struct uuid_command *)command;
            kernelUUID = SCUUIDString(uuidCommand->uuid);
            foundUUID = YES;
        }
        offset += command->cmdsize;
    }

    if (offset != commands.length) {
        result[@"error"] = @"kernel load-command table contains trailing data";
        return result;
    }
    if (!foundUUID || !kernelUUID.length) {
        result[@"error"] = @"kernel Mach-O does not contain LC_UUID";
        return result;
    }

    result[@"kernelUUID"] = kernelUUID;
    result[@"machOValidated"] = @YES;
    return result;
}

static BOOL SCWriteReport(NSDictionary *report, NSString **errorDescription) {
    if (geteuid() != 0) {
        if (errorDescription) *errorDescription = @"sckrwprobe must run as root";
        return NO;
    }

    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
    if (!json) {
        if (errorDescription) *errorDescription = error.localizedDescription ?: @"JSON serialization failed";
        return NO;
    }

    NSString *directory = SCReportPath.stringByDeletingLastPathComponent;
    mode_t previousMask = umask(0077);
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory
                                 withIntermediateDirectories:YES
                                                  attributes:@{NSFilePosixPermissions: @0700}
                                                       error:&error]) {
        umask(previousMask);
        if (errorDescription) *errorDescription = error.localizedDescription ?: @"Could not create report directory";
        return NO;
    }

    struct stat directoryInfo = {0};
    if (lstat(directory.fileSystemRepresentation, &directoryInfo) != 0 ||
        !S_ISDIR(directoryInfo.st_mode) ||
        S_ISLNK(directoryInfo.st_mode) ||
        directoryInfo.st_uid != 0 ||
        chmod(directory.fileSystemRepresentation, 0700) != 0) {
        umask(previousMask);
        if (errorDescription) *errorDescription = @"Report directory is not a secure root-owned directory";
        return NO;
    }

    if (![json writeToFile:SCReportPath options:NSDataWritingAtomic error:&error]) {
        umask(previousMask);
        if (errorDescription) *errorDescription = error.localizedDescription ?: @"Could not write report";
        return NO;
    }

    if (chmod(SCReportPath.fileSystemRepresentation, 0600) != 0) {
        umask(previousMask);
        if (errorDescription) *errorDescription = @"Could not secure report permissions";
        return NO;
    }

    struct stat reportInfo = {0};
    BOOL secureReport = lstat(SCReportPath.fileSystemRepresentation, &reportInfo) == 0 &&
        S_ISREG(reportInfo.st_mode) &&
        !S_ISLNK(reportInfo.st_mode) &&
        reportInfo.st_uid == 0 &&
        (reportInfo.st_mode & 0777) == 0600;
    umask(previousMask);
    if (!secureReport) {
        if (errorDescription) *errorDescription = @"Report file failed ownership or permission verification";
        return NO;
    }
    return YES;
}

static BOOL SCIsBooleanFalse(id value) {
    return [value isKindOfClass:NSNumber.class] && ![(NSNumber *)value boolValue];
}

static BOOL SCValidateReportContract(NSDictionary *report) {
    if (![report isKindOfClass:NSDictionary.class]) return NO;
    if (![report[@"schemaVersion"] isKindOfClass:NSNumber.class]) return NO;
    if ([report[@"schemaVersion"] integerValue] != 2) return NO;
    if (![report[@"mode"] isEqualToString:@"read-only"]) return NO;

    NSDictionary *safety = report[@"safety"];
    if (![safety isKindOfClass:NSDictionary.class]) return NO;

    NSString *transactionState = report[@"transactionState"];
    BOOL selfTestAttempted = [transactionState isEqualToString:@"selfTestVerified"] ||
        [transactionState isEqualToString:@"selfTestFailed"] ||
        [transactionState isEqualToString:@"quarantined"];

    NSDictionary *krw = report[@"krw"];
    if (![krw isKindOfClass:NSDictionary.class]) return NO;
    if (![krw[@"libraryPresent"] isKindOfClass:NSNumber.class]) return NO;
    if (![krw[@"kernelProbe"] isKindOfClass:NSDictionary.class]) return NO;

    BOOL vfsTestAttempted = [transactionState isEqualToString:@"vfsTestAttempted"] ||
        [transactionState isEqualToString:@"vfsTestVerified"] ||
        [transactionState isEqualToString:@"vfsTestFailed"] ||
        [transactionState isEqualToString:@"vfsTestQuarantined"] ||
        [transactionState isEqualToString:@"vfsTestUnsupported"];

    NSArray<NSString *> *alwaysFalseKeys = @[
        @"kcallCalled", @"physreadCalled", @"physwriteCalled",
        @"kernelMutationAllowed", @"artifactHidingEnabled"
    ];
    for (NSString *key in alwaysFalseKeys) {
        if (!SCIsBooleanFalse(safety[key])) return NO;
    }

    if (![safety[@"vnodeMutationCalled"] isKindOfClass:NSNumber.class]) return NO;
    if (!vfsTestAttempted && [safety[@"vnodeMutationCalled"] boolValue]) return NO;

    NSDictionary *selfTest = krw[@"primitiveSelfTest"];
    if (selfTestAttempted && ![selfTest isKindOfClass:NSDictionary.class]) return NO;

    NSArray<NSString *> *selfTestKeys = @[@"kwriteCalled", @"kmallocCalled", @"kdeallocCalled"];
    for (NSString *key in selfTestKeys) {
        if (![safety[key] isKindOfClass:NSNumber.class]) return NO;
    }
    if (!selfTestAttempted) {
        for (NSString *key in selfTestKeys) {
            if ([safety[key] boolValue]) return NO;
        }
    }

    NSDictionary *environment = report[@"environment"];
    if (![environment isKindOfClass:NSDictionary.class]) return NO;
    id bootTime = environment[@"bootTimeSeconds"];
    if (![bootTime isKindOfClass:NSNumber.class]) return NO;

    size_t boottimeSize = sizeof(struct timeval);
    struct timeval currentBoottime = {0};
    if (sysctlbyname("kern.boottime", &currentBoottime, &boottimeSize, NULL, 0) != 0) return NO;
    if ([bootTime integerValue] != currentBoottime.tv_sec) return NO;

    return YES;
}

static NSDictionary *SCReadCachedReport(NSString **errorDescription) {
    struct stat reportInfo = {0};
    if (lstat(SCReportPath.fileSystemRepresentation, &reportInfo) != 0 ||
        !S_ISREG(reportInfo.st_mode) ||
        S_ISLNK(reportInfo.st_mode) ||
        reportInfo.st_uid != 0 ||
        (reportInfo.st_mode & 0777) != 0600) {
        if (errorDescription) *errorDescription = @"No secure cached report is available";
        return nil;
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:SCReportPath options:0 error:&error];
    if (!data || data.length > 2 * 1024 * 1024) {
        if (errorDescription) *errorDescription = error.localizedDescription ?: @"Cached report could not be read";
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![json isKindOfClass:NSDictionary.class]) {
        if (errorDescription) *errorDescription = error.localizedDescription ?: @"Cached report is invalid";
        return nil;
    }
    if (!SCValidateReportContract(json)) {
        if (errorDescription) *errorDescription = @"Cached report failed safety contract or boot identity validation";
        return nil;
    }
    return json;
}

static NSString *SCSHA256Hash(const void *data, size_t length) {
    if (!data || length == 0) return @"";
    const uint8_t *bytes = data;
    uint64_t hash = 1469598103934665603ULL;
    for (size_t i = 0; i < length; i++) {
        hash ^= bytes[i];
        hash *= 1099511628211ULL;
    }
    return [NSString stringWithFormat:@"fnv1a64:%016llx", (unsigned long long)hash];
}

static NSArray<NSDictionary *> *SCKernelProfiles(void) {
    return @[
        @{
            @"profileID": @"iphone10-3-d22ap-20h364-28e24ce2",
            @"profileVersion": @1,
            @"productType": @"iPhone10,3",
            @"hardwareModel": @"D22AP",
            @"soc": @"T8015",
            @"osBuild": @"20H364",
            @"darwinRelease": @"22.6.0",
            @"kernelUUID": @"28E24CE2-BA1C-38B1-AC56-C0BE08A077BC",
            @"providerFamily": @"libkrw-dopamine",
            @"minimumCapabilityLevel": @"L4",
            @"vfsBackend": @YES,
            @"namecacheBackend": @NO,
            @"mutationAllowed": @NO,
            @"notes": @"Profile for iPhone X D22AP build 20H364. VFS test fixture enabled. No production vnode hiding."
        }
    ];
}

static NSString *SCDetectedProviderFamily(NSArray<NSString *> *loadedImages, NSString *loadedPath) {
    for (NSString *path in loadedImages.reverseObjectEnumerator) {
        if (![path isKindOfClass:NSString.class]) continue;
        NSString *name = path.lastPathComponent.lowercaseString;
        if ([name containsString:@"libkrw-dopamine"]) return @"libkrw-dopamine";
        if ([name containsString:@"palera1n"]) return @"libkrw-palera1n";
        if ([name containsString:@"checkra1n"]) return @"libkrw-checkra1n";
    }
    if ([loadedPath.lowercaseString containsString:@"libkrw"]) return @"libkrw";
    return @"unknown";
}

static NSDictionary *SCProfileMatchForReport(NSDictionary *report) {
    NSDictionary *environment = report[@"environment"];
    NSDictionary *sysctl = [environment isKindOfClass:NSDictionary.class] ? environment[@"sysctl"] : nil;
    NSDictionary *krw = report[@"krw"];
    NSDictionary *kernelProbe = [krw isKindOfClass:NSDictionary.class] ? krw[@"kernelProbe"] : nil;

    NSString *productType = [sysctl[@"productType"] isKindOfClass:NSString.class] ? sysctl[@"productType"] : @"";
    NSString *hardwareModel = [sysctl[@"hardwareModel"] isKindOfClass:NSString.class] ? sysctl[@"hardwareModel"] : @"";
    NSString *osBuild = [sysctl[@"osBuild"] isKindOfClass:NSString.class] ? sysctl[@"osBuild"] : @"";
    NSString *darwinRelease = [sysctl[@"osRelease"] isKindOfClass:NSString.class] ? sysctl[@"osRelease"] : @"";
    NSString *kernelUUID = [kernelProbe[@"kernelUUID"] isKindOfClass:NSString.class] ? kernelProbe[@"kernelUUID"] : @"";
    NSArray *loadedImages = [krw[@"loadedImages"] isKindOfClass:NSArray.class] ? krw[@"loadedImages"] : @[];
    NSString *loadedPath = [krw[@"loadedPath"] isKindOfClass:NSString.class] ? krw[@"loadedPath"] : @"";
    NSString *providerFamily = SCDetectedProviderFamily(loadedImages, loadedPath);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"matched"] = @NO;
    result[@"mutationAllowed"] = @NO;
    result[@"profileLevel"] = @"L0";
    result[@"providerFamily"] = providerFamily;
    result[@"required"] = @{
        @"productType": productType,
        @"hardwareModel": hardwareModel,
        @"osBuild": osBuild,
        @"darwinRelease": darwinRelease,
        @"kernelUUID": kernelUUID,
        @"providerFamily": providerFamily
    };

    for (NSDictionary *profile in SCKernelProfiles()) {
        BOOL match = [profile[@"productType"] isEqualToString:productType] &&
            [profile[@"hardwareModel"] isEqualToString:hardwareModel] &&
            [profile[@"osBuild"] isEqualToString:osBuild] &&
            [profile[@"darwinRelease"] isEqualToString:darwinRelease] &&
            [profile[@"kernelUUID"] isEqualToString:kernelUUID] &&
            [profile[@"providerFamily"] isEqualToString:providerFamily];
        if (!match) continue;

        result[@"matched"] = @YES;
        result[@"profileID"] = profile[@"profileID"];
        result[@"profileVersion"] = profile[@"profileVersion"];
        result[@"profileLevel"] = profile[@"minimumCapabilityLevel"] ?: @"L0";
        result[@"vfsBackend"] = profile[@"vfsBackend"] ?: @NO;
        result[@"namecacheBackend"] = profile[@"namecacheBackend"] ?: @NO;
        result[@"mutationAllowed"] = profile[@"mutationAllowed"] ?: @NO;
        result[@"notes"] = profile[@"notes"] ?: @"";
        break;
    }
    return result;
}

static NSDictionary *SCRunPrimitiveSelfTest(void *handle, SCKReadFunction kreadFunction) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"state"] = @"probing";
    result[@"kwriteVerified"] = @NO;
    result[@"kmallocVerified"] = @NO;
    result[@"kdeallocVerified"] = @NO;
    result[@"rollbackVerified"] = @NO;
    result[@"kmallocCalled"] = @NO;
    result[@"kwriteCalled"] = @NO;
    result[@"kdeallocCalled"] = @NO;

    SCKMallocFunction kmallocFunction = (SCKMallocFunction)dlsym(handle, "kmalloc");
    SCKWriteFunction kwriteFunction = (SCKWriteFunction)dlsym(handle, "kwrite");
    SCKDeallocFunction kdeallocFunction = (SCKDeallocFunction)dlsym(handle, "kdealloc");

    if (!kmallocFunction) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"kmalloc not exported";
        return result;
    }
    if (!kwriteFunction) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"kwrite not exported";
        return result;
    }
    if (!kdeallocFunction) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"kdealloc not exported";
        return result;
    }

    const size_t testSize = 64;
    uint64_t testAddress = 0;
    result[@"kmallocCalled"] = @YES;
    int allocStatus = kmallocFunction(&testAddress, testSize);
    result[@"kmallocStatus"] = SCStatusString(allocStatus);
    if (allocStatus != 0 || testAddress == 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"kmalloc failed";
        return result;
    }
    result[@"kmallocVerified"] = @YES;
    result[@"testAddress"] = SCHexAddress(testAddress);
    result[@"testSize"] = @(testSize);

    uint8_t originalData[64];
    memset(originalData, 0, testSize);
    int readOriginalStatus = kreadFunction(testAddress, originalData, testSize);
    result[@"readOriginalStatus"] = SCStatusString(readOriginalStatus);
    if (readOriginalStatus != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"kread of original allocation failed";
        result[@"kdeallocCalled"] = @YES;
        kdeallocFunction(testAddress, testSize);
        return result;
    }
    result[@"originalDataHash"] = SCSHA256Hash(originalData, testSize);

    uint8_t testPattern[64];
    for (size_t i = 0; i < testSize; i++) {
        testPattern[i] = (uint8_t)(0xA5 ^ (i & 0xFF));
    }
    result[@"kwriteCalled"] = @YES;
    int writeStatus = kwriteFunction(testPattern, testAddress, testSize);
    result[@"kwriteStatus"] = SCStatusString(writeStatus);
    if (writeStatus != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"kwrite of test pattern failed";
        result[@"kdeallocCalled"] = @YES;
        kdeallocFunction(testAddress, testSize);
        return result;
    }
    result[@"kwriteVerified"] = @YES;

    uint8_t readBackData[64];
    memset(readBackData, 0, testSize);
    int readBackStatus = kreadFunction(testAddress, readBackData, testSize);
    result[@"readBackStatus"] = SCStatusString(readBackStatus);
    BOOL patternMatch = readBackStatus == 0 && memcmp(readBackData, testPattern, testSize) == 0;
    result[@"patternMatch"] = @(patternMatch);

    // Once kwrite succeeds, always attempt rollback before returning.
    int restoreStatus = kwriteFunction(originalData, testAddress, testSize);
    result[@"restoreStatus"] = SCStatusString(restoreStatus);
    if (restoreStatus != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kwrite of original data failed during rollback";
        result[@"kdeallocCalled"] = @YES;
        kdeallocFunction(testAddress, testSize);
        return result;
    }

    uint8_t verifyRestoreData[64];
    memset(verifyRestoreData, 0, testSize);
    int verifyReadStatus = kreadFunction(testAddress, verifyRestoreData, testSize);
    result[@"verifyRestoreStatus"] = SCStatusString(verifyReadStatus);
    if (verifyReadStatus != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kread of restored data failed during rollback verification";
        result[@"kdeallocCalled"] = @YES;
        kdeallocFunction(testAddress, testSize);
        return result;
    }

    BOOL restoreMatch = verifyReadStatus == 0 && memcmp(verifyRestoreData, originalData, testSize) == 0;
    result[@"rollbackVerified"] = @(restoreMatch);
    if (!restoreMatch) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"restored data does not match original";
        result[@"kdeallocCalled"] = @YES;
        kdeallocFunction(testAddress, testSize);
        return result;
    }

    result[@"kdeallocCalled"] = @YES;
    int deallocStatus = kdeallocFunction(testAddress, testSize);
    result[@"kdeallocStatus"] = SCStatusString(deallocStatus);
    if (deallocStatus != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kdealloc failed";
        return result;
    }
    result[@"kdeallocVerified"] = @YES;

    if (readBackStatus != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"kread of test pattern failed; rollback succeeded";
        return result;
    }
    if (!patternMatch) {
        result[@"state"] = @"failed";
        result[@"error"] = @"written pattern did not match; rollback succeeded";
        return result;
    }
    result[@"state"] = @"verified";
    return result;
}

// Phase 2B: VFS test fixture backend
// Creates a test file, finds its vnode via proc/fd chain, toggles VISSHADOW,
// validates via access(), then restores original v_flags.
//
// The allproc symbol is found by scanning kernel __DATA,__common/__bss for a
// pointer whose target looks like a proc struct (valid p_pid at offset 0x60,
// valid le_next at offset 0x0). The proc list is walked to find the current
// process. The fd chain (proc -> filedesc -> ofiles[fd] -> fileproc ->
// fileglob -> vnode) is resolved by scanning struct layouts dynamically
// rather than relying on hardcoded offsets (except p_pid and v_flag).

static BOOL SCKernelPtrValid(uint64_t addr) {
    return addr >= 0xFFFFFFF000000000ULL;
}

// Find all proc_pid() accessor candidates in __TEXT/__TEXT_EXEC.
// proc_pid() decompiles to: return *(arg1 + p_pid_offset)
// ARM64: ldr w0, [x0, #imm]; ret
// Returns array of candidate offsets. The blog confirms p_pid=0x60 for
// iOS 16.7.x (XNU 8796), but we find all candidates and try each.
static size_t *SCFindAllPidOffsets(SCKReadFunction kread, uint64_t kernelBase,
                                    size_t *outCount) {
    *outCount = 0;
    struct mach_header_64 header = {0};
    if (kread(kernelBase, &header, sizeof(header)) != 0) return NULL;
    if (header.magic != MH_MAGIC_64 || header.ncmds == 0 || header.ncmds > SCMaxLoadCommands) return NULL;

    uint8_t *commands = malloc(header.sizeofcmds);
    if (!commands) return NULL;
    if (kread(kernelBase + sizeof(header), commands, header.sizeofcmds) != 0) {
        free(commands);
        return NULL;
    }

    int64_t slide = 0;
    struct { uint64_t base; uint64_t size; } segs[4];
    int segCount = 0;
    const uint8_t *ptr = commands;
    NSUInteger remaining = header.sizeofcmds;
    for (uint32_t i = 0; i < header.ncmds && remaining >= sizeof(struct load_command); i++) {
        const struct load_command *cmd = (const struct load_command *)ptr;
        if (cmd->cmdsize < sizeof(struct load_command) || cmd->cmdsize > remaining) break;
        if (cmd->cmd == LC_SEGMENT_64 && cmd->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)ptr;
            if (strcmp(seg->segname, "__TEXT") == 0) {
                slide = (int64_t)(kernelBase - seg->vmaddr);
            }
            if ((strcmp(seg->segname, "__TEXT") == 0 || strcmp(seg->segname, "__TEXT_EXEC") == 0) && segCount < 4) {
                segs[segCount].base = seg->vmaddr + slide;
                segs[segCount].size = seg->vmsize;
                segCount++;
            }
        }
        ptr += cmd->cmdsize;
        remaining -= cmd->cmdsize;
    }
    free(commands);
    if (segCount == 0) return NULL;

    // Collect unique offsets from ldr w0, [x0, #imm]; ret
    const size_t scanChunk = 8192;
    uint8_t *chunk = malloc(scanChunk);
    if (!chunk) return NULL;

    size_t *offsets = NULL;
    size_t offsetsCapacity = 0;

    for (int si = 0; si < segCount; si++) {
        uint64_t scanEnd = segs[si].size;
        if (scanEnd > 32 * 1024 * 1024) scanEnd = 32 * 1024 * 1024;

        for (uint64_t off = 0; off < scanEnd; off += scanChunk - 16) {
            size_t readSize = scanChunk;
            if (off + readSize > scanEnd) readSize = (size_t)(scanEnd - off);
            if (readSize < 16) break;

            if (kread(segs[si].base + off, chunk, readSize) != 0) continue;

            for (size_t i = 0; i + 8 <= readSize; i += 4) {
                uint32_t insn1 = *(uint32_t *)(chunk + i);
                uint32_t insn2 = *(uint32_t *)(chunk + i + 4);

                // ldr w0, [x0, #imm] followed by ret
                if ((insn1 & 0xFFC003FF) != 0xB9400000) continue;  // ldr w0, [x0, #imm]
                if (insn2 != 0xD65F03C0) continue;                   // ret

                size_t pidOff = ((insn1 >> 10) & 0xFFF) * 4;
                if (pidOff < 0x10 || pidOff > 0x200) continue;

                // Check if we already have this offset
                BOOL found = NO;
                for (size_t j = 0; j < *outCount; j++) {
                    if (offsets[j] == pidOff) { found = YES; break; }
                }
                if (found) continue;

                if (*outCount >= offsetsCapacity) {
                    offsetsCapacity = offsetsCapacity ? offsetsCapacity * 2 : 16;
                    offsets = realloc(offsets, offsetsCapacity * sizeof(size_t));
                    if (!offsets) { free(chunk); return NULL; }
                }
                offsets[(*outCount)++] = pidOff;
            }
        }
    }

    free(chunk);
    return offsets;
}

// Find current_proc() function address in kernel __TEXT segment.
// On arm64, current_proc() reads TPIDR_EL1 and follows pointers.
// We scan for the mrs instruction pattern and count matches for diagnostics.
typedef struct {
    uint64_t addr;
    uint64_t size;
    char name[17];
} SCKernelRange;

typedef struct {
    BOOL valid;
    uint64_t commonAddr;
    uint64_t commonSize;
    uint64_t bssAddr;
    uint64_t bssSize;
    uint64_t dataAddr;
    uint64_t dataSize;
    uint64_t segmentAddr;
    uint64_t segmentSize;
    uint64_t dataConstAddr;
    uint64_t dataConstSize;
    SCKernelRange dataRanges[SCMaxKernelRanges];
    uint32_t dataRangeCount;
    SCKernelRange textRanges[SCMaxKernelRanges];
    uint32_t textRangeCount;
} SCKernelDataSections;

static BOOL SCAddKernelRange(SCKernelRange *ranges, uint32_t *count,
                             uint64_t addr, uint64_t size, const char name[16]) {
    if (addr == 0 || size == 0 || *count >= SCMaxKernelRanges || addr > UINT64_MAX - size) return NO;
    for (uint32_t i = 0; i < *count; i++) {
        if (ranges[i].addr == addr && ranges[i].size == size) return YES;
    }
    SCKernelRange *range = &ranges[(*count)++];
    range->addr = addr;
    range->size = size;
    memcpy(range->name, name, 16);
    range->name[16] = '\0';
    return YES;
}

static BOOL SCParseDataSections(SCKReadFunction kread, uint64_t kernelBase,
                                 SCKernelDataSections *out) {
    memset(out, 0, sizeof(*out));
    out->valid = NO;

    struct mach_header_64 header = {0};
    if (kread(kernelBase, &header, sizeof(header)) != 0) return NO;
    if (header.magic != MH_MAGIC_64 || header.filetype != MH_EXECUTE) return NO;
    if (header.ncmds == 0 || header.ncmds > SCMaxLoadCommands) return NO;
    if (header.sizeofcmds < sizeof(struct load_command) || header.sizeofcmds > SCMaxLoadCommandBytes) return NO;

    uint8_t *commands = malloc(header.sizeofcmds);
    if (!commands) return NO;
    if (kread(kernelBase + sizeof(header), commands, header.sizeofcmds) != 0) {
        free(commands);
        return NO;
    }

    uint64_t textVmaddr = 0;
    BOOL foundText = NO;
    const uint8_t *ptr = commands;
    NSUInteger remaining = header.sizeofcmds;
    for (uint32_t i = 0; i < header.ncmds && remaining >= sizeof(struct load_command); i++) {
        const struct load_command *cmd = (const struct load_command *)ptr;
        if (cmd->cmdsize < sizeof(struct load_command) ||
            (cmd->cmdsize % 8) != 0 || cmd->cmdsize > remaining) {
            free(commands);
            return NO;
        }
        if (cmd->cmd == LC_SEGMENT_64 && cmd->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)ptr;
            if (SCMachNameEquals(seg->segname, "__TEXT")) {
                textVmaddr = seg->vmaddr;
                foundText = YES;
                break;
            }
        }
        ptr += cmd->cmdsize;
        remaining -= cmd->cmdsize;
    }
    if (!foundText) { free(commands); return NO; }

    int64_t slide = (int64_t)(kernelBase - textVmaddr);

    ptr = commands;
    remaining = header.sizeofcmds;
    for (uint32_t i = 0; i < header.ncmds && remaining >= sizeof(struct load_command); i++) {
        const struct load_command *cmd = (const struct load_command *)ptr;
        if (cmd->cmdsize < sizeof(struct load_command) ||
            (cmd->cmdsize % 8) != 0 || cmd->cmdsize > remaining) {
            free(commands);
            return NO;
        }
        if (cmd->cmd == LC_SEGMENT_64 && cmd->cmdsize >= sizeof(struct segment_command_64)) {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)ptr;
            BOOL isText = SCMachNameEquals(seg->segname, "__TEXT") ||
                SCMachNameEquals(seg->segname, "__TEXT_EXEC");
            BOOL isData = SCMachNameEquals(seg->segname, "__DATA") ||
                SCMachNameEquals(seg->segname, "__DATA_CONST") ||
                SCMachNameEquals(seg->segname, "__DATA_DIRTY");

            if (isText) {
                SCAddKernelRange(out->textRanges, &out->textRangeCount,
                                 seg->vmaddr + slide, seg->vmsize, seg->segname);
            }
            if (SCMachNameEquals(seg->segname, "__DATA")) {
                out->segmentAddr = seg->vmaddr + slide;
                out->segmentSize = seg->vmsize;
                if (seg->nsects > 0) {
                    const struct section_64 *sect = (const struct section_64 *)(ptr + sizeof(struct segment_command_64));
                    size_t sectionArraySize = (size_t)seg->nsects * sizeof(struct section_64);
                    if (sectionArraySize <= cmd->cmdsize - sizeof(struct segment_command_64)) {
                        for (uint32_t j = 0; j < seg->nsects; j++) {
                            if (SCMachNameEquals(sect[j].sectname, "__common")) {
                                out->commonAddr = sect[j].addr + slide;
                                out->commonSize = sect[j].size;
                            } else if (SCMachNameEquals(sect[j].sectname, "__bss")) {
                                out->bssAddr = sect[j].addr + slide;
                                out->bssSize = sect[j].size;
                            } else if (SCMachNameEquals(sect[j].sectname, "__data")) {
                                out->dataAddr = sect[j].addr + slide;
                                out->dataSize = sect[j].size;
                            }
                        }
                    }
                }
            } else if (SCMachNameEquals(seg->segname, "__DATA_CONST")) {
                out->dataConstAddr = seg->vmaddr + slide;
                out->dataConstSize = seg->vmsize;
            }

            if (isData && seg->nsects > 0) {
                const struct section_64 *sect = (const struct section_64 *)(ptr + sizeof(struct segment_command_64));
                size_t sectionArraySize = (size_t)seg->nsects * sizeof(struct section_64);
                if (sectionArraySize > cmd->cmdsize - sizeof(struct segment_command_64)) {
                    free(commands);
                    return NO;
                }
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    SCAddKernelRange(out->dataRanges, &out->dataRangeCount,
                                     sect[j].addr + slide, sect[j].size, sect[j].sectname);
                }
            } else if (isData) {
                SCAddKernelRange(out->dataRanges, &out->dataRangeCount,
                                 seg->vmaddr + slide, seg->vmsize, seg->segname);
            }
        }
        ptr += cmd->cmdsize;
        remaining -= cmd->cmdsize;
    }

    free(commands);
    out->valid = out->dataRangeCount > 0 && out->textRangeCount > 0;
    return out->valid;
}

// Offset cache: stores offsets relative to kernel base, keyed by kernel UUID.
// This allows a one-time exhaustive scan (slow) to be reused on subsequent runs.

typedef struct {
    BOOL valid;
    uint64_t allprocOffset;    // offset from kernel base
    size_t procListOffset;      // p_list.le_next offset in proc
    size_t procPidOffset;       // p_pid offset in proc
    size_t vflagOffset;         // v_flag offset in vnode
} SCOffsetCache;

static NSDictionary *SCLoadOffsetCache(NSString *kernelUUID, int64_t bootTime) {
    if (!kernelUUID.length) return nil;
    struct stat info = {0};
    if (lstat(SCOffsetCachePath.fileSystemRepresentation, &info) != 0 ||
        !S_ISREG(info.st_mode) || info.st_uid != 0 ||
        (info.st_mode & (S_IWGRP | S_IWOTH)) != 0 || info.st_size <= 0 ||
        info.st_size > 64 * 1024) return nil;
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:SCOffsetCachePath options:0 error:&error];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    if (![json[@"cacheVersion"] isKindOfClass:NSNumber.class] ||
        [json[@"cacheVersion"] unsignedIntValue] != SCOffsetCacheVersion) return nil;
    if (![json[@"kernelUUID"] isKindOfClass:NSString.class]) return nil;
    if (![json[@"kernelUUID"] isEqualToString:kernelUUID]) return nil;
    if (![json[@"allprocOffset"] isKindOfClass:NSString.class] ||
        ![json[@"procListOffset"] isKindOfClass:NSNumber.class] ||
        ![json[@"procPidOffset"] isKindOfClass:NSNumber.class]) return nil;
    return json;
}

static void SCSaveOffsetCache(NSString *kernelUUID, int64_t bootTime,
                               uint64_t allprocOffset, size_t procListOffset,
                               size_t procPidOffset, size_t vflagOffset) {
    if (!kernelUUID.length || bootTime <= 0) return;
    NSDictionary *cache = @{
        @"cacheVersion": @(SCOffsetCacheVersion),
        @"kernelUUID": kernelUUID,
        @"bootTimeSeconds": @(bootTime),
        @"allprocOffset": [NSString stringWithFormat:@"0x%016llx", (unsigned long long)allprocOffset],
        @"procListOffset": @(procListOffset),
        @"procPidOffset": @(procPidOffset),
        @"vflagOffset": @(vflagOffset)
    };
    NSString *dir = SCOffsetCachePath.stringByDeletingLastPathComponent;
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *json = [NSJSONSerialization dataWithJSONObject:cache options:NSJSONWritingPrettyPrinted error:nil];
    if (json) {
        [json writeToFile:SCOffsetCachePath options:NSDataWritingAtomic error:nil];
        chmod(SCOffsetCachePath.fileSystemRepresentation, 0600);
    }
}

static BOOL SCRangeContainsAddress(const SCKernelRange *ranges, uint32_t count,
                                    uint64_t address, size_t length) {
    if (length == 0 || address > UINT64_MAX - length) return NO;
    uint64_t end = address + length;
    for (uint32_t i = 0; i < count; i++) {
        uint64_t rangeEnd = ranges[i].addr + ranges[i].size;
        if (address >= ranges[i].addr && end <= rangeEnd) return YES;
    }
    return NO;
}

static size_t SCBuildPidOffsetOrder(const size_t *pidOffsets, size_t pidOffsetCount,
                                    size_t ordered[64]) {
    size_t count = 0;
    ordered[count++] = 0x60;
    for (size_t i = 0; i < pidOffsetCount && count < 64; i++) {
        size_t candidate = pidOffsets[i];
        if ((candidate % 4) != 0 || candidate > 0x200 || candidate == 0x60) continue;
        BOOL duplicate = NO;
        for (size_t j = 0; j < count; j++) {
            if (ordered[j] == candidate) { duplicate = YES; break; }
        }
        if (!duplicate) ordered[count++] = candidate;
    }
    return count;
}

static uint64_t SCValidateAllprocCandidate(SCKReadFunction kread, uint64_t allprocAddr,
                                            pid_t targetPid, const size_t *pidOffsets,
                                            size_t pidOffsetCount,
                                            NSMutableDictionary *diagnostics) {
    const size_t procReadSize = 0x208;
    size_t ordered[64];
    size_t orderedCount = SCBuildPidOffsetOrder(pidOffsets, pidOffsetCount, ordered);
    uint8_t first[0x208] = {0};
    uint8_t second[0x208] = {0};
    uint8_t third[0x208] = {0};
    uint8_t walk[0x208] = {0};
    uint64_t firstProc = 0;
    uint64_t firstLinks[2] = {0};
    uint64_t secondLinks[2] = {0};
    uint64_t thirdLinks[2] = {0};

    // allproc may have lock padding before lh_first (e.g. lck_rw_t = 16 bytes on newer XNU).
    // Try offsets 0, 8, 16, 24 to find the real lh_first pointer.
    uint64_t lhFirstAddr = 0;
    for (int hdrOff = 0; hdrOff <= 32; hdrOff += 8) {
        uint64_t candidate = 0;
        if (kread(allprocAddr + hdrOff, &candidate, sizeof(candidate)) != 0) continue;
        if (!SCKernelPtrValid(candidate)) continue;
        // Read le_prev from this candidate proc — it must point back to allprocAddr+hdrOff
        uint64_t leprev = 0;
        if (kread(candidate + 8, &leprev, sizeof(leprev)) != 0) continue;
        if (leprev != allprocAddr + hdrOff) continue;
        // Confirm: reading lhFirstAddr gives back the same candidate
        uint64_t confirm = 0;
        if (kread(leprev, &confirm, sizeof(confirm)) != 0) continue;
        if (confirm != candidate) continue;
        firstProc = candidate;
        lhFirstAddr = (uint64_t)(allprocAddr + hdrOff);
        break;
    }
    if (firstProc == 0 || lhFirstAddr == 0) return 0;

    if (kread(firstProc, firstLinks, sizeof(firstLinks)) != 0) return 0;
    uint64_t next1 = firstLinks[0];
    uint64_t prev1 = firstLinks[1];
    if (!SCKernelPtrValid(next1) || prev1 != lhFirstAddr) return 0;

    if (kread(next1, secondLinks, sizeof(secondLinks)) != 0) return 0;
    uint64_t next2 = secondLinks[0];
    uint64_t prev2 = secondLinks[1];
    if (!SCKernelPtrValid(next2) || prev2 != firstProc) return 0;

    if (kread(next2, thirdLinks, sizeof(thirdLinks)) != 0) return 0;
    uint64_t prev3 = thirdLinks[1];
    if (prev3 != next1) return 0;

    if (kread(firstProc, first, procReadSize) != 0 ||
        kread(next1, second, procReadSize) != 0 ||
        kread(next2, third, procReadSize) != 0) return 0;
    if (*(uint64_t *)(first + 0x00) != next1 ||
        *(uint64_t *)(second + 0x00) != next2 ||
        *(uint64_t *)(third + 0x08) != prev3) return 0;

    // allproc always begins with kernproc (pid=0). At least one of the first
    // three entries must have pid == 0, otherwise this is not allproc.
    size_t validatedPidOff = SIZE_MAX;
    for (size_t i = 0; i < orderedCount; i++) {
        size_t pidOff = ordered[i];
        uint32_t pid1 = *(uint32_t *)(first + pidOff);
        uint32_t pid2 = *(uint32_t *)(second + pidOff);
        uint32_t pid3 = *(uint32_t *)(third + pidOff);
        if (pid1 <= SCMaxPid && pid2 <= SCMaxPid && pid3 <= SCMaxPid &&
            pid1 != pid2 && pid1 != pid3 && pid2 != pid3 &&
            (pid1 == 0 || pid2 == 0 || pid3 == 0)) {
            validatedPidOff = pidOff;
            break;
        }
    }
    if (validatedPidOff == SIZE_MAX) return 0;

    uint64_t procAddr = firstProc;
    uint64_t expectedPrev = lhFirstAddr;
    int walkCount = 0;
    while (procAddr != 0 && walkCount < 4096) {
        if (procAddr == firstProc) memcpy(walk, first, procReadSize);
        else if (procAddr == next1) memcpy(walk, second, procReadSize);
        else if (procAddr == next2) memcpy(walk, third, procReadSize);
        else if (kread(procAddr, walk, procReadSize) != 0) break;

        uint64_t next = *(uint64_t *)(walk + 0x00);
        uint64_t prev = *(uint64_t *)(walk + 0x08);
        uint32_t pid = *(uint32_t *)(walk + validatedPidOff);
        if (prev != expectedPrev || pid > SCMaxPid) break;
        walkCount++;
        if (pid == (uint32_t)targetPid) {
            diagnostics[@"allprocAddress"] = SCHexAddress(allprocAddr);
            diagnostics[@"lhFirstAddress"] = SCHexAddress(lhFirstAddr);
            diagnostics[@"procListOffset"] = @0;
            diagnostics[@"procPidOffset"] = @(validatedPidOff);
            diagnostics[@"procAddress"] = SCHexAddress(procAddr);
            diagnostics[@"pidValidated"] = @YES;
            diagnostics[@"maxWalkLen"] = @(walkCount);
            return procAddr;
        }
        if (next == 0 || next == procAddr || !SCKernelPtrValid(next)) break;
        expectedPrev = procAddr;
        procAddr = next;
    }
    if (walkCount > [diagnostics[@"maxWalkLen"] intValue]) diagnostics[@"maxWalkLen"] = @(walkCount);
    return 0;
}

static BOOL SCDecodeADRP(uint32_t instruction, uint64_t pc, uint8_t *rd, uint64_t *page) {
    if ((instruction & 0x9F000000U) != 0x90000000U) return NO;
    uint64_t imm21 = ((uint64_t)((instruction >> 5) & 0x7FFFF) << 2) |
        ((instruction >> 29) & 0x3);
    int64_t signedImm = ((int64_t)(imm21 << 43)) >> 43;
    int64_t delta = signedImm << 12;
    *rd = instruction & 0x1F;
    *page = (uint64_t)((int64_t)(pc & ~0xFFFULL) + delta);
    return YES;
}

static uint64_t SCPatchfindAllproc(SCKReadFunction kread,
                                    const SCKernelDataSections *sections,
                                    pid_t targetPid, NSMutableDictionary *diagnostics,
                                    const size_t *pidOffsets, size_t pidOffsetCount) {
    const size_t chunkSize = 16384;
    uint8_t *chunk = malloc(chunkSize);
    if (!chunk) return 0;
    NSMutableSet<NSNumber *> *seenGlobals = [NSMutableSet set];
    int references = 0;
    int candidates = 0;

    for (uint32_t ri = 0; ri < sections->textRangeCount; ri++) {
        const SCKernelRange *range = &sections->textRanges[ri];
        for (uint64_t offset = 0; offset < range->size; offset += chunkSize - 32) {
            size_t readSize = chunkSize;
            if (offset + readSize > range->size) readSize = (size_t)(range->size - offset);
            if (readSize < 8 || kread(range->addr + offset, chunk, readSize) != 0) continue;

            for (size_t i = 0; i + 20 <= readSize; i += 4) {
                uint8_t adrpReg = 0;
                uint64_t page = 0;
                if (!SCDecodeADRP(*(uint32_t *)(chunk + i), range->addr + offset + i,
                                  &adrpReg, &page)) continue;
                for (size_t j = 4; j <= 16; j += 4) {
                    uint32_t instruction = *(uint32_t *)(chunk + i + j);
                    if ((instruction & 0xFFC00000U) != 0xF9400000U) continue;
                    if (((instruction >> 5) & 0x1F) != adrpReg) continue;
                    uint64_t globalAddr = page + (uint64_t)((instruction >> 10) & 0xFFF) * 8;
                    if (!SCRangeContainsAddress(sections->dataRanges, sections->dataRangeCount,
                                                globalAddr, sizeof(uint64_t))) continue;
                    references++;
                    NSNumber *key = @(globalAddr);
                    if ([seenGlobals containsObject:key]) continue;
                    [seenGlobals addObject:key];
                    candidates++;
                    uint64_t proc = SCValidateAllprocCandidate(kread, globalAddr, targetPid,
                                                               pidOffsets, pidOffsetCount,
                                                               diagnostics);
                    if (proc) {
                        diagnostics[@"allprocDiscovery"] = @"adrp-ldr";
                        diagnostics[@"allprocSection"] = [NSString stringWithUTF8String:range->name];
                        diagnostics[@"patchfindReferences"] = @(references);
                        diagnostics[@"patchfindCandidates"] = @(candidates);
                        free(chunk);
                        return proc;
                    }
                }
            }
        }
    }
    diagnostics[@"patchfindReferences"] = @(references);
    diagnostics[@"patchfindCandidates"] = @(candidates);
    free(chunk);
    return 0;
}

static uint64_t SCFindCurrentProc(SCKReadFunction kread,
                                   SCKernelDataSections *sections,
                                   pid_t targetPid,
                                   NSMutableDictionary *diagnostics,
                                   const size_t *pidOffsets, size_t pidOffsetCount) {
    uint64_t proc = SCPatchfindAllproc(kread, sections, targetPid, diagnostics,
                                      pidOffsets, pidOffsetCount);
    if (proc) return proc;

    const size_t chunkSize = 65536;
    uint8_t *chunk = malloc(chunkSize);
    if (!chunk) return 0;
    int pointerCandidates = 0;
    uint64_t bytesScanned = 0;

    for (uint32_t ri = 0; ri < sections->dataRangeCount; ri++) {
        const SCKernelRange *range = &sections->dataRanges[ri];
        for (uint64_t offset = 0; offset < range->size; offset += chunkSize - 8) {
            size_t readSize = chunkSize;
            if (offset + readSize > range->size) readSize = (size_t)(range->size - offset);
            if (readSize < 8 || kread(range->addr + offset, chunk, readSize) != 0) continue;
            bytesScanned += readSize;
            for (size_t i = 0; i + 8 <= readSize; i += 8) {
                uint64_t firstProc = *(uint64_t *)(chunk + i);
                if (!SCKernelPtrValid(firstProc)) continue;
                pointerCandidates++;
                uint64_t allprocAddr = range->addr + offset + i;
                proc = SCValidateAllprocCandidate(kread, allprocAddr, targetPid,
                                                  pidOffsets, pidOffsetCount,
                                                  diagnostics);
                if (proc) {
                    diagnostics[@"allprocDiscovery"] = @"data-scan";
                    diagnostics[@"allprocSection"] = [NSString stringWithUTF8String:range->name];
                    diagnostics[@"allprocOffset"] = @(offset + i);
                    diagnostics[@"scanCandidates"] = @(pointerCandidates);
                    diagnostics[@"dataBytesScanned"] = @(bytesScanned);
                    free(chunk);
                    return proc;
                }
            }
        }
    }

    diagnostics[@"scanCandidates"] = @(pointerCandidates);
    diagnostics[@"dataBytesScanned"] = @(bytesScanned);
    free(chunk);
    return 0;
}

// SCFollowFdChain walks: proc -> filedesc -> fd_ofiles[fd] -> fileproc ->
// fileglob -> vnode. All struct offsets are discovered dynamically.
// Returns vnode address, or 0 on failure. Also sets diagnostics["vflagOffset"].

static uint64_t SCFollowFdChain(SCKReadFunction kread, uint64_t procAddr, int fd,
                                 NSMutableDictionary *diagnostics) {
    const size_t procReadSize = 1024;
    uint8_t procData[1024];
    if (kread(procAddr, procData, procReadSize) != 0) {
        diagnostics[@"fdChainError"] = @"could not read proc struct";
        return 0;
    }

    // Scan proc struct for filedesc pointer: a kernel pointer that points to
    // a struct containing another kernel pointer (ofiles) at some offset,
    // where ofiles[fd] is also a valid kernel pointer (fileproc).
    uint64_t fdesc = 0;
    uint64_t ofiles = 0;
    uint64_t fileproc = 0;
    size_t fdOff = 0;
    size_t ofilesOff = 0;

    for (fdOff = 0; fdOff + 8 <= procReadSize; fdOff += 8) {
        uint64_t candidate = *(uint64_t *)(procData + fdOff);
        if (!SCKernelPtrValid(candidate)) continue;

        uint8_t fdescData[128];
        if (kread(candidate, fdescData, 128) != 0) continue;

        for (ofilesOff = 0; ofilesOff + 8 <= 128; ofilesOff += 8) {
            uint64_t ofilesCandidate = *(uint64_t *)(fdescData + ofilesOff);
            if (!SCKernelPtrValid(ofilesCandidate)) continue;

            uint64_t fpCandidate = 0;
            if (kread(ofilesCandidate + (uint64_t)fd * 8, &fpCandidate, 8) != 0) continue;
            if (!SCKernelPtrValid(fpCandidate)) continue;

            fdesc = candidate;
            ofiles = ofilesCandidate;
            fileproc = fpCandidate;
            break;
        }
        if (fdesc != 0) break;
    }

    if (fdesc == 0) {
        diagnostics[@"fdChainError"] = @"could not find filedesc pointer in proc struct";
        return 0;
    }

    diagnostics[@"procFdOffset"] = @(fdOff);
    diagnostics[@"fdescAddress"] = SCHexAddress(fdesc);
    diagnostics[@"fdescOfilesOffset"] = @(ofilesOff);
    diagnostics[@"ofilesAddress"] = SCHexAddress(ofiles);
    diagnostics[@"fileprocAddress"] = SCHexAddress(fileproc);

    // Scan fileproc struct for fileglob pointer: a kernel pointer that points
    // to a struct containing another kernel pointer (vnode) at some offset,
    // where the vnode has a reasonable v_flags value.
    uint8_t fpData[128];
    if (kread(fileproc, fpData, 128) != 0) {
        diagnostics[@"fdChainError"] = @"could not read fileproc struct";
        return 0;
    }

    uint64_t fileglob = 0;
    uint64_t vnodeAddr = 0;
    size_t fgOff = 0;
    size_t dataOff = 0;
    size_t vflagOff = 0;

    for (fgOff = 0; fgOff + 8 <= 128 && vnodeAddr == 0; fgOff += 8) {
        uint64_t fgCandidate = *(uint64_t *)(fpData + fgOff);
        if (!SCKernelPtrValid(fgCandidate)) continue;

        uint8_t fgData[256];
        if (kread(fgCandidate, fgData, 256) != 0) continue;

        for (dataOff = 0; dataOff + 8 <= 256 && vnodeAddr == 0; dataOff += 8) {
            uint64_t vnodeCandidate = *(uint64_t *)(fgData + dataOff);
            if (!SCKernelPtrValid(vnodeCandidate)) continue;

            // Read vnode struct and scan for v_flags: a 4-byte value that is
            // non-zero, < 0xFFFFF, and does not have VISSHADOW set.
            uint8_t vnodeData[256];
            if (kread(vnodeCandidate, vnodeData, 256) != 0) continue;

            for (size_t voff = 4; voff + 4 <= 256; voff += 4) {
                uint32_t flags = *(uint32_t *)(vnodeData + voff);
                if (flags == 0 || flags == 0xFFFFFFFF || flags > 0xFFFFF) continue;
                if (flags & VISSHADOW) continue;
                // Heuristic: v_type (int32, 1-8 for VREG..VBAD) should appear
                // somewhere in the 16 bytes before v_flag. v_type, v_tag,
                // v_lflag, v_id may all be between v_type and v_flag.
                BOOL hasVtype = NO;
                for (size_t toff = voff >= 20 ? voff - 20 : 0; toff + 4 <= voff; toff += 4) {
                    int32_t maybeType = (int32_t)*(uint32_t *)(vnodeData + toff);
                    if (maybeType >= 1 && maybeType <= 8) { hasVtype = YES; break; }
                }
                if (!hasVtype) continue;

                fileglob = fgCandidate;
                vnodeAddr = vnodeCandidate;
                vflagOff = voff;
                break;
            }
        }
    }

    if (vnodeAddr == 0) {
        diagnostics[@"fdChainError"] = @"could not find vnode via fileproc -> fileglob chain";
        return 0;
    }

    diagnostics[@"fileprocFgOffset"] = @(fgOff);
    diagnostics[@"fileglobAddress"] = SCHexAddress(fileglob);
    diagnostics[@"fileglobDataOffset"] = @(dataOff);
    diagnostics[@"vnodeAddress"] = SCHexAddress(vnodeAddr);
    diagnostics[@"vflagOffset"] = @(vflagOff);
    return vnodeAddr;
}

static NSDictionary *SCRunVFSTest(SCKBaseFunction kbaseFunction,
                                   SCKReadFunction kreadFunction,
                                   SCKWriteFunction kwriteFunction,
                                   NSString *kernelUUID) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"state"] = @"probing";
    result[@"vnodeHideVerified"] = @NO;
    result[@"syscallVerified"] = @NO;
    result[@"rollbackVerified"] = @NO;
    result[@"vnodeMutationCalled"] = @NO;

    uint64_t kernelBase = 0;
    if (kbaseFunction(&kernelBase) != 0 || !SCValidateKernelAddress(kernelBase)) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"could not get kernel base";
        result[@"vnodeAddress"] = @"0x0";
        return result;
    }
    result[@"kernelBase"] = SCHexAddress(kernelBase);

    SCKernelDataSections sections = {0};
    if (!SCParseDataSections(kreadFunction, kernelBase, &sections)) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"could not parse kernel __DATA sections";
        result[@"vnodeAddress"] = @"0x0";
        return result;
    }
    result[@"commonSectionAddr"] = SCHexAddress(sections.commonAddr);
    result[@"commonSectionSize"] = @(sections.commonSize);
    result[@"bssSectionAddr"] = SCHexAddress(sections.bssAddr);
    result[@"bssSectionSize"] = @(sections.bssSize);
    result[@"dataSectionAddr"] = SCHexAddress(sections.dataAddr);
    result[@"dataSectionSize"] = @(sections.dataSize);
    result[@"dataSegmentAddr"] = SCHexAddress(sections.segmentAddr);
    result[@"dataSegmentSize"] = @(sections.segmentSize);
    result[@"dataConstSegmentAddr"] = SCHexAddress(sections.dataConstAddr);
    result[@"dataConstSegmentSize"] = @(sections.dataConstSize);

    NSString *fixturePath = @"/var/root/Library/Logs/iOSSpoof/vfs_test_fixture";
    NSString *fixtureDir = [fixturePath stringByDeletingLastPathComponent];
    [NSFileManager.defaultManager createDirectoryAtPath:fixtureDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:nil];
    chmod(fixtureDir.fileSystemRepresentation, 0700);

    const char *path = fixturePath.fileSystemRepresentation;
    int fd = open(path, O_CREAT | O_RDWR | O_TRUNC, 0600);
    if (fd < 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"could not create test fixture file";
        return result;
    }
    write(fd, "iOSSpoof-VFS-Test\n", 18);
    lseek(fd, 0, SEEK_SET);
    result[@"fixturePath"] = fixturePath;

    int accessBefore = access(path, F_OK);
    result[@"accessBeforeHide"] = @(accessBefore == 0);
    if (accessBefore != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"test fixture not accessible before hide";
        close(fd);
        unlink(path);
        return result;
    }

    pid_t targetPid = getpid();
    result[@"targetPid"] = @(targetPid);

    // Get kernel UUID and boottime for cache validation
    int64_t bootTime = 0;
    {
        struct timeval bt = {0};
        size_t btsz = sizeof(bt);
        if (sysctlbyname("kern.boottime", &bt, &btsz, NULL, 0) == 0) bootTime = bt.tv_sec;
    }

    // Try loading cached offsets first
    NSDictionary *cachedOffsets = SCLoadOffsetCache(kernelUUID, bootTime);
    uint64_t procAddr = 0;

    if (cachedOffsets) {
        result[@"offsetCache"] = @"hit";
        uint64_t allprocOffset = SCParseHexAddress(cachedOffsets[@"allprocOffset"]);
        size_t cachedPidOff = [cachedOffsets[@"procPidOffset"] unsignedIntegerValue];
        size_t cachedListOff = [cachedOffsets[@"procListOffset"] unsignedIntegerValue];

        if (allprocOffset > 0 && allprocOffset <= UINT64_MAX - kernelBase &&
            cachedListOff == 0 && cachedPidOff > 0 && cachedPidOff <= 0x200 &&
            (cachedPidOff % 4) == 0) {
            uint64_t allprocAddr = kernelBase + allprocOffset;
            result[@"cachedAllprocAddr"] = SCHexAddress(allprocAddr);
            result[@"cachedProcListOffset"] = @(cachedListOff);
            result[@"cachedProcPidOffset"] = @(cachedPidOff);
            procAddr = SCValidateAllprocCandidate(kreadFunction, allprocAddr, targetPid,
                                                  &cachedPidOff, 1, result);
            if (procAddr) result[@"procSource"] = @"cache";
            else result[@"offsetCache"] = @"rejected";
        } else {
            result[@"offsetCache"] = @"rejected";
        }
    } else {
        result[@"offsetCache"] = @"miss";
    }

    result[@"currentProcKcall"] = @"disabled-untrusted-signature";

    // Fast path: XNU 8796 has p_list at 0 and p_pid at 0x60. Patchfind
    // allproc references first, then scan data sections if code references fail.
    if (procAddr == 0) {
        procAddr = SCFindCurrentProc(kreadFunction, &sections, targetPid, result, NULL, 0);
    }

    // Generic fallback: collect accessor-shaped offsets only if the exact
    // profile offset did not validate.
    if (procAddr == 0) {
        size_t pidOffsetCount = 0;
        size_t *pidOffsets = SCFindAllPidOffsets(kreadFunction, kernelBase, &pidOffsetCount);
        NSMutableArray *offsetStrings = [NSMutableArray array];
        for (size_t i = 0; i < pidOffsetCount; i++) {
            [offsetStrings addObject:[NSString stringWithFormat:@"0x%zx", pidOffsets[i]]];
        }
        result[@"procPidOffsetsFromAccessors"] = offsetStrings;
        result[@"procPidOffsetCount"] = @(pidOffsetCount);

        procAddr = SCFindCurrentProc(kreadFunction, &sections, targetPid, result,
                                     pidOffsets, pidOffsetCount);
        free(pidOffsets);
    }
    if (procAddr) {
        result[@"procSource"] = @"allproc";
        uint64_t allprocOffset = 0;
        if (result[@"allprocAddress"]) {
            uint64_t allprocAbs = SCParseHexAddress(result[@"allprocAddress"]);
            if (allprocAbs > kernelBase) allprocOffset = allprocAbs - kernelBase;
        }
        size_t cachedListOff = [result[@"procListOffset"] unsignedIntegerValue];
        size_t cachedPidOff = [result[@"procPidOffset"] unsignedIntegerValue];
        if (allprocOffset > 0 && cachedPidOff > 0) {
            SCSaveOffsetCache(kernelUUID, bootTime, allprocOffset, cachedListOff, cachedPidOff, 0);
            result[@"offsetCacheSaved"] = @YES;
        }
    }
    if (procAddr == 0) {
        result[@"state"] = @"unsupported";
        result[@"error"] = @"could not find current proc from validated allproc candidates";
        result[@"vnodeAddress"] = @"0x0";
        close(fd);
        unlink(path);
        return result;
    }

    uint64_t vnodeAddr = SCFollowFdChain(kreadFunction, procAddr, fd, result);
    if (vnodeAddr == 0) {
        result[@"state"] = @"unsupported";
        result[@"error"] = result[@"fdChainError"] ?: @"could not follow fd chain to vnode";
        result[@"vnodeAddress"] = @"0x0";
        close(fd);
        unlink(path);
        return result;
    }

    size_t vflagOff = [result[@"vflagOffset"] unsignedIntegerValue];
    result[@"vnodeAddress"] = SCHexAddress(vnodeAddr);

    uint32_t originalFlags = 0;
    if (kreadFunction(vnodeAddr + vflagOff, &originalFlags, 4) != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"could not read vnode v_flags";
        close(fd);
        unlink(path);
        return result;
    }
    result[@"originalVFlags"] = [NSString stringWithFormat:@"0x%08x", originalFlags];

    if (originalFlags & VISSHADOW) {
        result[@"state"] = @"failed";
        result[@"error"] = @"VISSHADOW already set on vnode; v_flags offset may be incorrect";
        close(fd);
        unlink(path);
        return result;
    }

    uint32_t newFlags = originalFlags ^ VISSHADOW;
    result[@"vnodeMutationCalled"] = @YES;
    int writeStatus = kwriteFunction(&newFlags, vnodeAddr + vflagOff, 4);
    result[@"vflagsWriteStatus"] = SCStatusString(writeStatus);
    if (writeStatus != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"kwrite failed to toggle VISSHADOW";
        close(fd);
        unlink(path);
        return result;
    }

    uint32_t afterWriteFlags = 0;
    if (kreadFunction(vnodeAddr + vflagOff, &afterWriteFlags, 4) != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kread failed to verify v_flags after write; attempting restore";
        kwriteFunction(&originalFlags, vnodeAddr + vflagOff, 4);
        close(fd);
        unlink(path);
        return result;
    }
    result[@"afterWriteVFlags"] = [NSString stringWithFormat:@"0x%08x", afterWriteFlags];
    if (afterWriteFlags != newFlags) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"v_flags write did not produce expected value; restoring";
        kwriteFunction(&originalFlags, vnodeAddr + vflagOff, 4);
        close(fd);
        unlink(path);
        return result;
    }
    result[@"vnodeHideVerified"] = @YES;

    int accessAfterHide = access(path, F_OK);
    result[@"accessAfterHide"] = @(accessAfterHide == 0);
    result[@"syscallVerified"] = @(accessAfterHide != 0);

    int restoreStatus = kwriteFunction(&originalFlags, vnodeAddr + vflagOff, 4);
    result[@"vflagsRestoreStatus"] = SCStatusString(restoreStatus);
    if (restoreStatus != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kwrite failed to restore original v_flags";
        close(fd);
        unlink(path);
        return result;
    }

    uint32_t verifyFlags = 0;
    if (kreadFunction(vnodeAddr + vflagOff, &verifyFlags, 4) != 0) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"kread failed to verify v_flags restoration";
        close(fd);
        unlink(path);
        return result;
    }
    result[@"restoredVFlags"] = [NSString stringWithFormat:@"0x%08x", verifyFlags];
    result[@"rollbackVerified"] = @(verifyFlags == originalFlags);

    int accessAfterRestore = access(path, F_OK);
    result[@"accessAfterRestore"] = @(accessAfterRestore == 0);

    if (verifyFlags != originalFlags) {
        result[@"state"] = @"quarantined";
        result[@"error"] = @"v_flags was not restored correctly";
    } else if (accessAfterHide == 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"file remained visible after VISSHADOW toggle; v_flags offset may be incorrect";
    } else if (accessAfterRestore != 0) {
        result[@"state"] = @"failed";
        result[@"error"] = @"file not accessible after v_flags restoration";
    } else {
        result[@"state"] = @"verified";
    }

    close(fd);
    unlink(path);
    return result;
}

static NSDictionary *SCBuildReport(BOOL shouldRunSelfTest, BOOL shouldRunVFSTest) {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    report[@"schemaVersion"] = @2;
    report[@"probeVersion"] = SCProbeVersion;
    report[@"timestamp"] = [formatter stringFromDate:NSDate.date];
    report[@"mode"] = @"read-only";
    report[@"safety"] = [NSMutableDictionary dictionaryWithDictionary:@{
        @"kwriteCalled": @NO,
        @"kcallCalled": @NO,
        @"kmallocCalled": @NO,
        @"kdeallocCalled": @NO,
        @"physreadCalled": @NO,
        @"physwriteCalled": @NO,
        @"vnodeMutationCalled": @NO,
        @"kernelMutationAllowed": @NO,
        @"artifactHidingEnabled": @NO
    }];
    report[@"environment"] = SCRealEnvironment();

    NSMutableArray<NSDictionary *> *attempts = [NSMutableArray array];
    NSString *loadedPath = nil;
    void *handle = SCOpenKRWLibrary(&loadedPath, attempts);
    NSMutableDictionary *krw = [NSMutableDictionary dictionary];
    krw[@"libraryPresent"] = @(handle != NULL);
    krw[@"loadAttempts"] = attempts;
    krw[@"loadedPath"] = loadedPath ?: @"";

    if (!handle) {
        krw[@"exports"] = @{};
        krw[@"loadedImages"] = @[];
        krw[@"kernelProbe"] = @{ @"error": @"libkrw could not be loaded" };
        report[@"krw"] = krw;
        report[@"profileMatch"] = SCProfileMatchForReport(report);
        return report;
    }

    NSDictionary *exports = SCExportReport(handle);
    krw[@"exports"] = exports;

    SCKBaseFunction kbaseFunction = (SCKBaseFunction)dlsym(handle, "kbase");
    SCKReadFunction kreadFunction = (SCKReadFunction)dlsym(handle, "kread");
    if (kbaseFunction && kreadFunction) {
        krw[@"kernelProbe"] = SCProbeKernel(kbaseFunction, kreadFunction);
    } else {
        krw[@"kernelProbe"] = @{ @"error": @"required kbase or kread export is missing" };
    }

    BOOL canRunSelfTest = shouldRunSelfTest &&
                       [[exports objectForKey:@"kmalloc"] boolValue] &&
                       [[exports objectForKey:@"kwrite"] boolValue] &&
                       [[exports objectForKey:@"kdealloc"] boolValue] &&
                       kreadFunction != NULL &&
                       [[krw[@"kernelProbe"] objectForKey:@"machOValidated"] boolValue];

    if (canRunSelfTest) {
        NSDictionary *selfTest = SCRunPrimitiveSelfTest(handle, kreadFunction);
        krw[@"primitiveSelfTest"] = selfTest;

        NSMutableDictionary *safety = [report[@"safety"] mutableCopy];
        safety[@"kmallocCalled"] = @([selfTest[@"kmallocCalled"] boolValue]);
        safety[@"kdeallocCalled"] = @([selfTest[@"kdeallocCalled"] boolValue]);
        safety[@"kwriteCalled"] = @([selfTest[@"kwriteCalled"] boolValue]);
        report[@"safety"] = safety;

        NSString *selfTestState = selfTest[@"state"];
        if ([selfTestState isEqualToString:@"verified"]) {
            report[@"transactionState"] = @"selfTestVerified";
        } else if ([selfTestState isEqualToString:@"quarantined"]) {
            report[@"transactionState"] = @"quarantined";
        } else if ([selfTestState isEqualToString:@"failed"]) {
            report[@"transactionState"] = @"selfTestFailed";
        } else {
            report[@"transactionState"] = selfTestState ?: @"unknown";
        }
    } else {
        krw[@"primitiveSelfTest"] = @{ @"state": @"skipped", @"reason": @"missing required exports or verified kread" };
        report[@"transactionState"] = @"readOnly";
    }
    BOOL canRunVFSTest = shouldRunVFSTest &&
        kbaseFunction != NULL &&
        kreadFunction != NULL &&
        [[exports objectForKey:@"kwrite"] boolValue] &&
        [[krw[@"kernelProbe"] objectForKey:@"machOValidated"] boolValue];

    if (canRunVFSTest) {
        SCKWriteFunction kwriteFunction = (SCKWriteFunction)dlsym(handle, "kwrite");
        if (kwriteFunction) {
            NSString *vfsKernelUUID = krw[@"kernelProbe"][@"kernelUUID"];
            if (![vfsKernelUUID isKindOfClass:NSString.class]) vfsKernelUUID = @"";
            NSDictionary *vfsTest = SCRunVFSTest(kbaseFunction, kreadFunction, kwriteFunction, vfsKernelUUID);
            krw[@"vfsTest"] = vfsTest;

            NSMutableDictionary *safety = [report[@"safety"] mutableCopy];
            safety[@"vnodeMutationCalled"] = @([vfsTest[@"vnodeMutationCalled"] boolValue]);
            report[@"safety"] = safety;

            NSString *vfsState = vfsTest[@"state"];
            if ([vfsState isEqualToString:@"verified"]) {
                report[@"transactionState"] = @"vfsTestVerified";
            } else if ([vfsState isEqualToString:@"failed"]) {
                report[@"transactionState"] = @"vfsTestFailed";
            } else if ([vfsState isEqualToString:@"quarantined"]) {
                report[@"transactionState"] = @"vfsTestQuarantined";
            } else if ([vfsState isEqualToString:@"unsupported"]) {
                report[@"transactionState"] = @"vfsTestUnsupported";
            } else {
                report[@"transactionState"] = @"vfsTestAttempted";
            }
        } else {
            krw[@"vfsTest"] = @{ @"state": @"skipped", @"reason": @"kwrite not available" };
        }
    } else {
        krw[@"vfsTest"] = @{ @"state": @"skipped", @"reason": @"missing required exports or verified kread" };
    }

    krw[@"loadedImages"] = SCLoadedKRWImages();
    report[@"krw"] = krw;
    report[@"profileMatch"] = SCProfileMatchForReport(report);
    dlclose(handle);
    return report;
}

static void SCPrintUsage(void) {
    fprintf(stderr,
            "Usage: sckrwprobe [--stdout] [--cached] [--selftest] [--vfstest] [--help]\n"
            "  --stdout     Run read-only probe and print JSON to stdout\n"
            "  --cached     Return the existing cached report without loading libkrw\n"
            "  --selftest   Run read-only probe then controlled kwrite self-test\n"
            "  --vfstest    Run read-only probe then VFS vnode test fixture\n"
            "  --help       Show this help\n"
            "Report: %s\n",
            SCReportPath.fileSystemRepresentation);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BOOL printJSON = NO;
        BOOL cachedOnly = NO;
        BOOL selfTest = NO;
        BOOL vfsTest = NO;
        for (int index = 1; index < argc; index++) {
            if (strcmp(argv[index], "--stdout") == 0) {
                printJSON = YES;
            } else if (strcmp(argv[index], "--cached") == 0) {
                printJSON = YES;
                cachedOnly = YES;
            } else if (strcmp(argv[index], "--selftest") == 0) {
                printJSON = YES;
                selfTest = YES;
            } else if (strcmp(argv[index], "--vfstest") == 0) {
                printJSON = YES;
                vfsTest = YES;
            } else if (strcmp(argv[index], "--help") == 0 || strcmp(argv[index], "-h") == 0) {
                SCPrintUsage();
                return 0;
            } else {
                fprintf(stderr, "Unknown argument: %s\n", argv[index]);
                SCPrintUsage();
                return 64;
            }
        }

        if (geteuid() != 0) {
            fprintf(stderr, "sckrwprobe must run as root\n");
            return 77;
        }

        // setuid helpers may start as uid=mobile/euid=root. Some KRW providers
        // check the real uid too, so normalize all ids before loading libkrw.
        setgid(0);
        setuid(0);

        int savedStdout = -1;
        if (printJSON && !cachedOnly) {
            fflush(stdout);
            savedStdout = dup(STDOUT_FILENO);
            if (savedStdout >= 0) {
                dup2(STDERR_FILENO, STDOUT_FILENO);
            }
        }

        NSString *cachedError = nil;
        NSDictionary *report = cachedOnly ? SCReadCachedReport(&cachedError) : SCBuildReport(selfTest, vfsTest);

        if (savedStdout >= 0) {
            fflush(stdout);
            dup2(savedStdout, STDOUT_FILENO);
            close(savedStdout);
        }

        if (!report) {
            fprintf(stderr, "%s\n", cachedError.UTF8String ?: "No cached report is available");
            return 2;
        }

        if (cachedOnly) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
            if (json) {
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
                return 0;
            }
            return 2;
        }

        if (!SCValidateReportContract(report)) {
            fprintf(stderr, "Fresh report failed safety contract validation\n");
            return 2;
        }

        NSString *writeError = nil;
        BOOL wroteReport = SCWriteReport(report, &writeError);

        if (printJSON) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
            if (json) {
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
            }
        }

        if (!wroteReport) {
            fprintf(stderr, "Failed to write report: %s\n", writeError.UTF8String ?: "unknown error");
            return 1;
        }

        NSDictionary *kernelProbe = report[@"krw"][@"kernelProbe"];
        BOOL verified = [kernelProbe[@"machOValidated"] boolValue];
        fprintf(stderr, "Read-only report written to %s\n", SCReportPath.fileSystemRepresentation);
        return verified ? 0 : 2;
    }
}
