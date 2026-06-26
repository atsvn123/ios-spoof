#import <Foundation/Foundation.h>

/**
 * SCProxyManager
 *
 * Quản lý transparent proxy ở mức process:
 *  - Đọc config proxy từ SCSpoofConfig
 *  - Giao tiếp với scproxyd (daemon chạy root) qua Unix domain socket
 *  - Bật/tắt PF divert rules
 *  - Cập nhật upstream SOCKS5/HTTP endpoint
 *
 * Daemon scproxyd làm việc chính:
 *  - PF anchor "com.iosspoof.proxy" rdr-to divert port cho TCP outbound
 *  - PF rdr-to local DoH resolver cho UDP/53
 *  - Userspace relay: divert socket <-> SOCKS5 upstream
 *  - Hỗ trợ UDP associate nếu upstream SOCKS5 hỗ trợ UDP
 *
 * Cách hoạt động anti-detect:
 *  - KHÔNG set system proxy (Settings) -> CFNetworkCopySystemProxySettings rỗng (hook đảm bảo)
 *  - Traffic bị PF divert ở kernel level, app không thấy interface VPN
 *  - getifaddrs hook ẩn utun/ppp (nếu dùng NE tunnel fallback)
 *  - DNS resolve qua DoH (HTTPS 443) -> không leak qua 53
 */
@interface SCProxyManager : NSObject

+ (instancetype)shared;

/** Bật transparent proxy toàn cục. Trả YES nếu daemon chấp nhận. */
- (BOOL)startProxy;

/** Tắt. */
- (BOOL)stopProxy;

/** Trạng thái hiện tại. */
- (BOOL)isRunning;

/** Ping daemon, trả về version string. */
- (NSString *)daemonVersion;

/** Cập nhật upstream (gọi khi prefs đổi). */
- (BOOL)updateUpstream;

@end
