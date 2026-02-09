//
//  main.swift
//  smc-write
//
//  Privileged SMC write helper for AirBattery charge limit feature.
//  Usage: smc-write <KEY> <VALUE>
//    KEY:   BCLM (Intel, value 20-100) or CHWA (Apple Silicon, value 0 or 1)
//    VALUE: Integer value to write
//
//  This tool must be run as root to write SMC keys.
//

import Foundation
import IOKit

// MARK: - SMC Types (minimal copy from SMCController.swift)

typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                      UInt8, UInt8, UInt8, UInt8)

struct SMCParamStruct {
    enum Selector: UInt8 {
        case kSMCHandleYPCEvent  = 2
        case kSMCWriteKey        = 6
    }

    struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct SMCKeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
}

// MARK: - Main

func printUsage() {
    fputs("Usage: smc-write <KEY> <VALUE>\n", stderr)
    fputs("  KEY:   BCLM (value 20-100) or CHWA (value 0 or 1)\n", stderr)
    fputs("  VALUE: Integer value to write\n", stderr)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    printUsage()
    exit(1)
}

let keyName = args[1].uppercased()
guard let value = Int(args[2]) else {
    fputs("Error: VALUE must be an integer\n", stderr)
    exit(1)
}

// Validate key and value
let smcKeyCode: FourCharCode
switch keyName {
case "BCLM":
    guard (20...100).contains(value) else {
        fputs("Error: BCLM value must be 20-100\n", stderr)
        exit(1)
    }
    smcKeyCode = FourCharCode(fromString: "BCLM")
case "CHWA":
    guard value == 0 || value == 1 else {
        fputs("Error: CHWA value must be 0 or 1\n", stderr)
        exit(1)
    }
    smcKeyCode = FourCharCode(fromString: "CHWA")
default:
    fputs("Error: KEY must be BCLM or CHWA\n", stderr)
    exit(1)
}

// Open AppleSMC
var masterPort: mach_port_t = 0
IOMasterPort(UInt32(MACH_PORT_NULL), &masterPort)

let service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"))
guard service != 0 else {
    fputs("Error: AppleSMC driver not found\n", stderr)
    exit(2)
}

var connection: io_connect_t = 0
let openResult = IOServiceOpen(service, mach_task_self_, 0, &connection)
IOObjectRelease(service)

guard openResult == kIOReturnSuccess else {
    fputs("Error: Failed to open AppleSMC (code \(openResult))\n", stderr)
    exit(2)
}

defer { IOServiceClose(connection) }

// Write SMC key
var inputStruct = SMCParamStruct()
inputStruct.key = smcKeyCode
inputStruct.bytes.0 = UInt8(value)
inputStruct.keyInfo.dataSize = 1
inputStruct.data8 = SMCParamStruct.Selector.kSMCWriteKey.rawValue

var outputStruct = SMCParamStruct()
let inputSize = MemoryLayout<SMCParamStruct>.stride
var outputSize = MemoryLayout<SMCParamStruct>.stride

let writeResult = IOConnectCallStructMethod(connection,
                                            UInt32(SMCParamStruct.Selector.kSMCHandleYPCEvent.rawValue),
                                            &inputStruct,
                                            inputSize,
                                            &outputStruct,
                                            &outputSize)

guard writeResult == kIOReturnSuccess else {
    if writeResult == kIOReturnNotPrivileged {
        fputs("Error: Root privileges required\n", stderr)
    } else {
        fputs("Error: SMC write failed (code \(writeResult))\n", stderr)
    }
    exit(3)
}

guard outputStruct.result == 0 else {
    fputs("Error: SMC returned error \(outputStruct.result)\n", stderr)
    exit(3)
}

print("OK")
exit(0)
