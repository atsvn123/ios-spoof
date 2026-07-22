# iOSSpoof

Advanced iOS device spoofer with transparent proxy, carrier/GPS spoofing, and anti-detection. Built for rootless/roothide jailbreaks.

## Features

### Device Spoofing
- **12 presets**: iPhone 8 / X / 11 / 12 / 13 / 13 Pro / 14 / 14 Pro / 14 Pro Max / 15 / 15 Pro / 15 Pro Max
- Full specs per preset: ProductType, HardwareModel, BoardId, ChipId, screen resolution/scale/PPI, capacity, color
- UDID (40-hex), Serial Number, ECID, IMEI (Luhn-valid), MAC, IDFA — generated per-bundle, persisted
- Hooks: `UIDevice`, `sysctlbyname` (hw.machine/model/serial/UUID), `IOKit` (IOPlatformExpertDevice), `uname`, `ASIdentifierManager`, `UIScreen` (bounds/scale), battery

### Carrier & Network Spoofing
- `CTCarrier`: carrierName, MCC, MNC, ISO country code
- `CTTelephonyNetworkInfo`: radio access technology (LTE / 5G NR / 3G)
- Anti-detect proxy: `CFNetworkCopySystemProxySettings` returns empty, `SCDynamicStoreCopyValue` hides proxy/VPN keys
- `getifaddrs` filter: hides `utun`/`ppp`/`ipsec`/`tap`/`tun`/`gif` interfaces
- `if_nametoindex` / `if_indextoname`: rename VPN interfaces to `lo0`

### GPS / Location Spoofing
- `CLLocationManager`: location, heading, authorization, significant location changes
- `CLLocation`: coordinate, altitude, accuracy, course, speed, timestamp
- `CLGeocoder`: reverse geocode uses spoofed coordinates
- `MKMapView`: region, center, camera
- `CLCircularRegion`: containsCoordinate always YES

### Jailbreak Hiding
- `access` / `stat` / `lstat` / `open`: hide `/var/jb`, `/Applications/Cydia.app`, Sileo, Zebra, ellekit, etc.
- `getenv`: hide `DYLD_INSERT_LIBRARIES`, `SUBSTRATE_HOME`, `ELLEKIT_HOME`
- `UIApplication canOpenURL:`: block `cydia://`, `sileo://`, `filza://` schemes
- `fork` hook

### Transparent Proxy (Anti-Detect)
- **PF divert**: kernel-level packet redirect, no system proxy settings
- **SOCKS5 / HTTP CONNECT** upstream support with auth
- **SOCKS5 UDP associate** for UDP traffic (DNS, QUIC, gaming)
- **NAT table**: 4-tuple flow tracking (src/sport/dst/dport → upstream socket)
- **DNS-over-HTTPS**: local resolver on 127.0.0.1:5353, queries go through tunnel (no DNS leak)
- **PF anchor** `com.iosspoof.proxy`: TCP → divert port, UDP/53 → DoH resolver
- App cannot detect proxy: `CFNetworkCopySystemProxySettings` empty, no VPN interface visible

## Architecture

```
┌─────────────────────────────────────────────────┐
│  App (App Store)                                │
│  ↓ UIDevice / sysctl / IOKit / CLLocation / ... │
│  ↓ (hooked by iOSSpoof.dylib)                   │
├─────────────────────────────────────────────────┤
│  Tweak (iOSSpoof.dylib)                         │
│  SCSpoofConfig ← preferences plist              │
│  SCDevicePresets (12 models)                    │
│  SCProxyManager → Unix socket → scproxyd        │
├─────────────────────────────────────────────────┤
│  scproxyd (root daemon)                         │
│  PF divert → NAT table → SOCKS5/HTTP upstream   │
│  DoH resolver (127.0.0.1:5353)                  │
├─────────────────────────────────────────────────┤
│  Kernel (PF)                                    │
│  rdr TCP → 127.0.0.1:7773 (divert)              │
│  rdr UDP/53 → 127.0.0.1:5353 (DoH)              │
└─────────────────────────────────────────────────┘
```

## File Structure

```
ios-spoof/
├── Makefile                  # Theos rootless build
├── control                   # Debian package metadata
├── iOSSpoof.plist            # MobileSubstrate filter (all processes)
├── src/
│   ├── SCDevicePresets.h/m   # 12 iPhone presets, ID generators
│   ├── SCSpoofConfig.h/m     # Config reader, per-bundle override
│   ├── Tweak.x               # Device hooks (UIDevice/sysctl/IOKit/AdSupport/jailbreak)
│   ├── SCNetworkHooks.x      # Carrier + proxy/VPN hide hooks
│   ├── SCGeoHooks.x          # GPS/CLLocation/MapKit hooks
│   ├── SCProxyManager.h/m    # In-tweak client → scproxyd IPC
├── daemon/
│   ├── scproxyd.m            # PF divert + NAT + SOCKS5/HTTP + DoH
│   ├── Makefile
│   └── com.iosspoof.scproxyd.plist  # launchd plist
├── prefs/
│   ├── Root.plist            # Settings UI spec
│   ├── SCRootListController.m
│   ├── entry.plist
│   └── Makefile
└── .github/workflows/build.yml  # CI build
```

## Build

### Read-only KRW diagnostic

The package includes `sckrwprobe`, an optional read-only diagnostic tool. It dynamically loads `libkrw` when available, records exported capabilities, calls only `kbase` and `kread`, validates the in-memory kernel Mach-O header, and extracts `LC_UUID`.

It does not call `kwrite`, `kcall`, `kmalloc`, `physwrite`, or modify kernel state. It does not run automatically and `libkrw` is not a mandatory package dependency.

Run it as root on a test device:

```sh
/var/jb/usr/bin/sckrwprobe --stdout
```

The current package is rootless. The local report is written as a root-owned file with mode `0600` to:

```text
/var/root/Library/Logs/iOSSpoof/sckrwprobe.json
```

Exit codes:

- `0`: kernel Mach-O and UUID verified successfully.
- `1`: the local JSON report could not be written.
- `2`: the report was written, but libkrw or the read-only kernel probe was unavailable or unverified.
- `64`: invalid command-line argument.
- `77`: the tool was not run as root.

### Requirements
- macOS with Xcode 15+
- [Theos](https://theos.dev) installed at `$THEOS`
- iPhoneOS SDK (16.5+)

### Local build
```bash
export THEOS=~/theos
make package FINALPACKAGE=1
```

Output: `packages/com.iosspoof.tweak_1.0.0_iphoneos-arm.deb`

### GitHub Actions (recommended for Windows users)
Push to `main` or tag `v1.0.0`. The workflow in `.github/workflows/build.yml`:
1. Installs Theos on macOS runner
2. Builds the .deb (rootless)
3. Uploads as artifact
4. Creates GitHub Release on tag

For safe builds, the default filter uses `Classes = UIApplication` (only GUI apps, not system daemons). The tweak **does nothing** unless you add target app bundle IDs in **Settings → iOSSpoof → Target Apps**.

To target an app:

1. Install the package.
2. Open **Settings → iOSSpoof**.
3. Enter the app's bundle ID in **Target Apps** (comma-separated for multiple).
4. Enable spoofing and configure.
5. Tap **Áp dụng & Respring**.

Do **not** use `Executables = *` on a daily device.

### Install
```bash
# Copy .deb to device
scp packages/*.deb root@<device>:/var/root/

# SSH to device
ssh root@<device>
dpkg -i /var/root/com.iosspoof.tweak_1.0.0_iphoneos-arm.deb
killall -9 SpringBoard
```

## Usage

1. Open **Settings → iOSSpoof**
2. Enter target app bundle IDs in **Target Apps** (e.g. `com.example.app`)
3. Enable **Bật Spoofing**
4. Select device preset (iPhone 8 → 15 Pro Max, or Random)
5. Configure carrier (default: Viettel, VN, 5G NR)
6. Configure GPS coordinates (default: Hanoi 21.0285, 105.8542)
7. Configure proxy:
   - Enable **Transparent Proxy**
   - Type: SOCKS5 or HTTP CONNECT
   - Host/Port/User/Pass of your upstream
   - Enable UDP if your SOCKS5 supports UDP associate
8. Anti-detect: enable Hide Proxy, Hide VPN, Hide Jailbreak
9. Tap **Áp dụng & Respring**

## How Anti-Detect Proxy Works

Traditional proxy (Settings → WiFi → HTTP Proxy) is trivially detected:
```swift
CFNetworkCopySystemProxySettings()  // returns proxy dict
getifaddrs()  // shows utun0, ppp0
```

iOSSpoof uses **kernel-level PF divert** instead:
1. `scproxyd` loads PF rules: `rdr TCP → 127.0.0.1:7773`, `rdr UDP/53 → 127.0.0.1:5353`
2. TCP traffic captured at kernel level (before app sees it)
3. NAT table maps 4-tuple → upstream SOCKS5/HTTP socket
4. DNS queries go to local DoH resolver → HTTPS 443 → also tunneled
5. Tweak hooks `CFNetworkCopySystemProxySettings()` → returns empty dict
6. Tweak hooks `getifaddrs()` → filters `utun`/`ppp`/`ipsec`

Result: App sees no proxy, no VPN interface, no DNS leak.

## Safe Mode / Bootloop Notes

The package is **safe-by-default**:

- The tweak filter uses `Classes = UIApplication` — only GUI apps are injected, never system daemons.
- The tweak **does nothing** unless target bundle IDs are configured in Settings.
- `scproxyd` LaunchDaemon is not packaged for automatic boot loading by default.
- Select target app bundle IDs in **Settings → iOSSpoof → Target Apps**.

Do **not** use `Executables = *` on a daily device. Injecting into all system processes can bootloop the device, especially on rootless/roothide jailbreaks.

If a bootloop happens:

1. Hard reboot.
2. Boot jailbreak with tweaks disabled.
3. Remove the package: `dpkg -r com.iosspoof.tweak`.
4. If needed, delete `/var/jb/Library/MobileSubstrate/DynamicLibraries/iOSSpoof.*` and `/var/jb/Library/LaunchDaemons/com.iosspoof.scproxyd.plist`.

## Notes

- Tweak injects only into GUI apps that match `Classes = UIApplication`; hooks are only installed for apps listed in **Target Apps** in Settings.
- Apps installed from App Store work normally — no need to install via roothide manager
- `scproxyd` is installed as a tool at `/var/jb/usr/bin/scproxyd`, but is not auto-loaded at boot by default.

## Config Schema

Preferences plist: `/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist`

```xml
<dict>
  <key>enabled</key>            <true/>
  <key>productType</key>        <string>iPhone15,2</string>
  <key>randomizeOnLaunch</key>  <false/>
  <key>carrierName</key>        <string>Viettel</string>
  <key>carrierMCC</key>         <string>452</string>
  <key>carrierMNC</key>         <string>04</string>
  <key>carrierISO</key>         <string>vn</string>
  <key>radioTech</key>          <string>CTRadioAccessTechnologyNRNSA</string>
  <key>geoEnabled</key>         <true/>
  <key>latitude</key>           <real>21.0285</real>
  <key>longitude</key>          <real>105.8542</real>
  <key>proxyEnabled</key>       <true/>
  <key>proxyType</key>          <string>socks5</string>
  <key>proxyHost</key>          <string>127.0.0.1</string>
  <key>proxyPort</key>          <integer>1080</integer>
  <key>proxyUser</key>          <string></string>
  <key>proxyPass</key>          <string></string>
  <key>proxyUDP</key>           <true/>
  <key>hideProxy</key>          <true/>
  <key>hideVPN</key>            <true/>
  <key>hideJailbreak</key>      <true/>
  <key>spoofIDFA</key>          <true/>
  <key>spoofIDFV</key>          <true/>
  <key>spoofBattery</key>       <true/>
  <key>bundleOverrides</key>
  <dict>
    <key>com.example.app</key>
    <dict>
      <key>productType</key>   <string>iPhone14,7</string>
    </dict>
  </dict>
</dict>
```

## License

MIT
