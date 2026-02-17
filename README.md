#
<p align="center">
<img src="./AirBattery/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="200" height="200" />
<h1 align="center">AirBattery Swoosh</h1>
<h3 align="center">See battery levels of all your devices on Mac — in the Dock, status bar, and widgets.</h3>
</p>

## Download

**[Download the latest DMG](../../releases/latest)** — open it and drag AirBattery Swoosh to Applications.

> On first launch, macOS may show a security warning. Right-click the app and select **Open** to bypass it.

## Screenshots
<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./img/preview_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="./img/preview.png">
  <img alt="AirBattery Swoosh Screenshots" src="./img/preview.png" width="840"/>
</picture>
</p>

## Features

- Automatically detects AirPods, Magic Mouse, Magic Keyboard, Magic Trackpad, iPhone, iPad, Apple Watch, Apple Pencil, and third-party Bluetooth HID devices
- Shows battery levels in the **menu bar**, **Dock**, and **lock screen / desktop widgets**
- **Nearcast**: share battery info between your Macs over the local network
- Pin specific devices to the menu bar as real-time battery icons
- Set battery alerts with custom thresholds and sounds
- CLI tool (`airbattery`) for terminal-based battery queries
- Supports macOS 11.0 and later

## Usage

1. Launch AirBattery Swoosh — it appears in both the Dock and status bar by default (configurable)
2. Click the Dock or status bar icon to see all device battery levels
3. Add widgets to your desktop or lock screen for at-a-glance monitoring
4. Use **Nearcast** to view batteries of your other Macs and their peripherals on the same network
5. Hide, pin, or set alerts for any device from the context menu

## FAQ

**Why isn't my iPhone / iPad / Apple Watch showing up?**
> Make sure the iPhone/iPad has trusted this Mac and was connected via USB cable at least once while AirBattery Swoosh was running. After pairing, it just needs to be on the same Wi-Fi network.

**Does my Apple Watch need to be connected separately?**
> No. When AirBattery Swoosh detects a paired iPhone via Wi-Fi or USB, it automatically reads the Apple Watch battery paired with it. (Bluetooth-only iPhone discovery doesn't support Watch battery reading.)

**What does the warning symbol next to a device name mean?**
> It means the device hasn't updated its battery info in over 10 minutes — it may be offline or turned off.

**Can I get iPhone battery without Wi-Fi?**
> Yes — enable **iPhone / iPad (Cellular) over BT** in preferences and keep Bluetooth on. Only works with iPhones and cellular iPads.

**Why does AirBattery Swoosh need Bluetooth permission?**
> It captures Bluetooth advertisement packets from nearby devices to read their battery levels.

## Build from Source

```bash
git clone https://github.com/hzeng412/AirBattery.git
cd AirBattery
./build.sh              # Build + create DMG
./build.sh --install    # Build + install to /Applications
./build.sh --launch     # Build + install + launch
```

Requires Xcode and macOS 11.0+.

## Credits

AirBattery Swoosh is a fork of [AirBattery](https://github.com/lihaoyun6/AirBattery) by [@lihaoyun6](https://github.com/lihaoyun6). Thanks for creating the original project.

### Libraries used

- [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice) — iPhone/iPad USB detection (bundled binary based on `73b6fd1`)
- [comptest](https://gist.github.com/nikias/ebc6e975dc908f3741af0f789c5b1088) by @nikias — companion test utility
- [MultipeerKit](https://github.com/insidegui/MultipeerKit) by @insidegui — LAN peer-to-peer communication for Nearcast
- [Sparkle](https://github.com/sparkle-project/Sparkle) — auto-update framework
