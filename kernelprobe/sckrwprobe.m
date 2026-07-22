#import <Foundation/Foundation.h>

#include <dlfcn.h>
#include <errno.h>
#include <mach/machine.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <uuid/uuid.h>

typedef int (*SCKBaseFunction)(uint64_t *address);
typedef int (*SCKReadFunction)(uint64_t address, void *buffer, size_t length);

static NSString * const SCProbeVersion = @"1";
static NSString * const SCReportPath = @"/var/root/Library/Logs/iOSSpoof/sckrwprobe.json";
static const uint32_t SCMaxLoadCommands = 4096;
static const uint32_t SCMaxLoadCommandBytes = 4 * 1024 * 1024;

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
    return environment;
}

static NSArray<NSString *> *SCKRWLibraryCandidates(void) {
    return @[
        @"libkrw.0.dylib",
        @"libkrw.dylib",
        @"/usr/lib/libkrw.0.dylib",
        @"/usr/lib/libkrw.dylib",
        @"/var/jb/usr/lib/libkrw.0.dylib",
        @"/var/jb/usr/lib/libkrw.dylib"
    ];
}

static void *SCOpenKRWLibrary(NSString **loadedPath, NSMutableArray<NSDictionary *> *attempts) {
    for (NSString *candidate in SCKRWLibraryCandidates()) {
        dlerror();
        void *handle = dlopen(candidate.UTF8String, RTLD_NOW | RTLD_LOCAL);
        const char *error = dlerror();
        [attempts addObject:@{
            @"path": candidate,
            @"opened": @(handle != NULL),
            @"error": error ? [NSString stringWithUTF8String:error] : @""
        }];
        if (handle) {
            if (loadedPath) *loadedPath = candidate;
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

static NSDictionary *SCBuildReport(void) {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    report[@"schemaVersion"] = @1;
    report[@"probeVersion"] = SCProbeVersion;
    report[@"timestamp"] = [formatter stringFromDate:NSDate.date];
    report[@"mode"] = @"read-only";
    report[@"safety"] = @{
        @"kwriteCalled": @NO,
        @"kcallCalled": @NO,
        @"kernelMutationAllowed": @NO,
        @"artifactHidingEnabled": @NO
    };
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
    krw[@"loadedImages"] = SCLoadedKRWImages();
    report[@"krw"] = krw;
    dlclose(handle);
    return report;
}

static void SCPrintUsage(void) {
    fprintf(stderr,
            "Usage: sckrwprobe [--stdout] [--help]\n"
            "Runs a read-only libkrw capability and kernel identity probe.\n"
            "Report: %s\n",
            SCReportPath.fileSystemRepresentation);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BOOL printJSON = NO;
        for (int index = 1; index < argc; index++) {
            if (strcmp(argv[index], "--stdout") == 0) {
                printJSON = YES;
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

        NSDictionary *report = SCBuildReport();
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
