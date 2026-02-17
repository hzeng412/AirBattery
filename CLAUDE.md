# AirBattery Swoosh - Project Guide

## Overview
macOS menu bar app that monitors battery levels of Bluetooth peripherals (AirPods, Magic Mouse, Apple Pencil, iPhone/iPad, etc.), the Mac's internal battery, and third-party HID devices. Displays via menu bar popover, dock icon, lock screen/desktop widgets, and a CLI tool.

## Build & Run
```bash
./build.sh           # Build Release and install to /Applications
./build.sh --launch  # Build, install, and launch
```
- Scheme: `AirBattery`, Configuration: `Release`
- Code signing: Automatic, Team ID `37SCFKRLNW`

## Targets
| Target | Product | Purpose |
|--------|---------|---------|
| AirBattery | AirBattery Swoosh.app | Main menu bar app |
| AirBatteryWidgetExtension | .appex | Lock screen & desktop widgets |
| AirBatteryHelper | AirBatteryHelper.app | Login launch agent (embedded in main app) |
| abt | CLI executable | Terminal battery query tool (symlinked to /usr/local/bin/airbattery) |

## File Map

### Core App (`AirBattery/Supports/`)
| File | Purpose |
|------|---------|
| `AirBatteryApp.swift` | App delegate, menu bar status item, popover window, dock window, timer setup, Bluetooth event handling, Nearcast init, Sparkle updates, URL scheme handler |
| `Supports.swift` | Global utilities: `getPowerColor()`, `getDeviceIcon()`, battery formatting, LogReader (HID log parser), device name/model lookup, timer publishers, View/String/NSImage extensions |
| `CommandLineTool.swift` | CLI tool install/uninstall (`/usr/local/bin/airbattery` symlink), `runAsRoot()` via AppleScript |
| `Multipeer.swift` | Nearcast: MultipeerKit-based sharing of battery data between nearby Macs |
| `Sparkle.swift` | Auto-update UI (check for updates menu item, update preferences) |
| `BTTool.swift` | Bluetooth connect/disconnect via IOBluetoothDevice |
| `AppleScript.swift` | Scriptable commands: listAll, getUsage, getStatus, reloadAll |
| `GroupForm.swift` | Custom SwiftUI form components for settings (SForm, SGroupBox, SToggle, SPicker) |
| `InfoButton.swift` | Custom info button NSControl with popover |
| `WindowAccessor.swift` | NSViewRepresentable to access native NSWindow for settings |
| `logReader.sh` | Shell script for incremental syslog parsing of HID battery events |

### UI Screens (`AirBattery/ViewModel/`)
| File | Purpose |
|------|---------|
| `ContentView.swift` | **Main popover/dock UI**: battery card list, device grouping, hidden devices section, Nearcast section, power wattage graph, context menus |
| `SettingsView.swift` | **Settings window**: General, Display, Nearbility (BT filtering), Nearcast, Widget, Blacklist, Debug tabs |
| `BatteryView.swift` | Reusable battery bar component (25.5x12), charging bolt/plug icons, color by level |
| `BatteryAlertView.swift` | Battery alert configuration dialog, threshold settings, notification triggers |

### Battery Detection (`AirBattery/BatteryInfo/`)
| File | Device Type | Detection Method |
|------|-------------|------------------|
| `BLEBattery.swift` | AirPods, Beats, Apple Pencil | CoreBluetooth BLE advertisement scanning (manufacturer data 0x4c00) |
| `MagicBattery.swift` | Magic Mouse, Keyboard, Trackpad | `system_profiler SPBluetoothDataType` JSON parsing |
| `InternalBattery.swift` | Mac internal battery | IOKit IOPowerSources (capacity, health, voltage, watts, adapter info) |
| `IDeviceBattery.swift` | iPhone, iPad | libimobiledevice USB detection (bundled in Resources) |
| `BTDBattery.swift` | Third-party HID devices | macOS syslog parsing for Bluetooth HID battery events |
| `AirBatteryModel.swift` | **Central data store**: Device struct, in-memory list, CRUD operations, UserDefaults persistence for widgets, Nearcast data, blacklist/hidden filtering |

### Widgets (`widget/`)
| File | Purpose |
|------|---------|
| `BatteryWidget.swift` | Primary widget: timeline providers, small/medium layouts, reads from UserDefaults widget store |
| `BatteryWidget2.swift` | Large widget: 11-device list, dual-column layout, stale data warning |
| `BatteryWidget3.swift` | Compact variants: small 2-device carousel, medium compact layout |
| `widgetBundle.swift` | Widget bundle registration, conditional macOS 14+ support |
| `AppIntent.swift` | Widget configuration intent (device name parameter) |

### Helper App (`AirBatteryHelper/`)
| File | Purpose |
|------|---------|
| `AirBatteryHelperApp.swift` | Launch-at-login agent: checks if main app is running, launches if not |
| `main.swift` | Helper app entry point |

### CLI Tool (`abt/`)
| File | Purpose |
|------|---------|
| `main.swift` | ArgumentParser CLI: `--nearcast`, `--json`, `--csv` flags; reads widget UserDefaults; table/JSON/CSV output |

### Config
| File | Purpose |
|------|---------|
| `AirBattery/Info.plist` | Bundle config: name "AirBattery Swoosh", URL scheme `airbattery://`, Sparkle feed, AppleScript support |
| `AirBattery.entitlements` | Main app entitlements (currently empty) |
| `AirBattery.xcodeproj/project.pbxproj` | Xcode project: 4 targets, SPM deps (Sparkle, MultipeerKit, ArgumentParser) |
| `build.sh` | Build & install script |

### Localization
- English (`en.lproj`), Simplified Chinese (`zh-Hans.lproj`), Traditional Chinese (`zh-Hant.lproj`)
- Files: `Localizable.strings`, `InfoPlist.strings`, `Credits.rtf`

## Data Flow
```
Scanners (BLE/Magic/HID/iDevice/Internal) -> AirBatteryModel.updateDevice()
    -> In-memory cache -> AirBatteryModel.writeData() -> UserDefaults (widget store)
    -> Widget/MenuBar/Dock reads and displays
```

## Key UserDefaults
`showOn`, `updateInterval`, `launchAtLogin`, `intBattOnStatusBar`, `readBTDevice`, `readBTHID`, `readIDevice`, `readPencil`, `ncGroupID`, `alertList`, `blackList`, `pinnedList`, `batteryPercent`, `hideLevel`

## Common Edit Patterns
- **Add new device type**: Create scanner in `BatteryInfo/`, register timer in `AirBatteryApp.swift`, add icon in `Supports.swift` (`getDeviceIcon`)
- **Change popover UI**: Edit `ContentView.swift`
- **Change widget layout**: Edit `BatteryWidget.swift` / `BatteryWidget2.swift` / `BatteryWidget3.swift`
- **Add settings option**: Edit `SettingsView.swift`, add UserDefaults key
- **Change battery colors**: Edit `getPowerColor()` in `Supports.swift`
- **Rename app**: `PRODUCT_NAME` in `project.pbxproj`, `CFBundleDisplayName`/`CFBundleName` in `Info.plist`, `Localizable.strings`
- **Power wattage graph**: `ContentView.swift` (search for power/watt/graph)
