//
//  SMCController.swift
//  AirBattery
//
//  Battery charge limit control via SMC (BCLM/CHWA keys)
//  Based on zackelia/bclm and SMCKit
//

import Foundation
import IOKit

// MARK: - Type Aliases

public typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8)

// MARK: - SMC Param Struct

public struct SMCParamStruct {
    public enum Selector: UInt8 {
        case kSMCHandleYPCEvent  = 2
        case kSMCReadKey         = 5
        case kSMCWriteKey        = 6
        case kSMCGetKeyFromIndex = 8
        case kSMCGetKeyInfo      = 9
    }

    public enum Result: UInt8 {
        case kSMCSuccess     = 0
        case kSMCError       = 1
        case kSMCKeyNotFound = 132
    }

    public struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    public struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    public struct SMCKeyInfoData {
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

// MARK: - FourCharCode Extension

public extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
    
    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

// MARK: - SMC Key and DataType

public struct SMCKey {
    let code: FourCharCode
    let info: DataType
}

public struct DataType: Equatable {
    let type: FourCharCode
    let size: UInt32
}

// MARK: - SMC Controller

public class SMCController {
    
    public enum SMCError: Error {
        case driverNotFound
        case failedToOpen
        case keyNotFound(code: String)
        case notPrivileged
        case unknown(kIOReturn: kern_return_t, SMCResult: UInt8)
    }
    
    private var connection: io_connect_t = 0
    
    // SMC Keys for battery charge limit
    // BCLM = Battery Charge Level Max (Intel)
    // CHWA = Charge When Available (Apple Silicon - 80% limit toggle)
    private let bclmKey = SMCKey(code: FourCharCode(fromString: "BCLM"),
                                  info: DataType(type: FourCharCode(fromString: "ui8 "), size: 1))
    private let chwaKey = SMCKey(code: FourCharCode(fromString: "CHWA"),
                                  info: DataType(type: FourCharCode(fromString: "ui8 "), size: 1))
    
    public static let shared = SMCController()
    
    /// Check if running on Apple Silicon
    public var isAppleSilicon: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.hasPrefix("arm64")
    }
    
    // MARK: - Connection Management
    
    public func open() throws {
        // Use mach_port_t equivalent for compatibility with macOS 11+
        var masterPort: mach_port_t = 0
        let kr = IOMasterPort(UInt32(MACH_PORT_NULL), &masterPort)
        if kr != KERN_SUCCESS {
            masterPort = 0 // fallback
        }
        
        let service = IOServiceGetMatchingService(masterPort,
                                                  IOServiceMatching("AppleSMC"))
        if service == 0 { throw SMCError.driverNotFound }
        
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        
        if result != kIOReturnSuccess { throw SMCError.failedToOpen }
    }
    
    @discardableResult
    public func close() -> Bool {
        let result = IOServiceClose(connection)
        return result == kIOReturnSuccess
    }
    
    // MARK: - SMC Read/Write
    
    private func readData(_ key: SMCKey) throws -> SMCBytes {
        var inputStruct = SMCParamStruct()
        inputStruct.key = key.code
        inputStruct.keyInfo.dataSize = UInt32(key.info.size)
        inputStruct.data8 = SMCParamStruct.Selector.kSMCReadKey.rawValue
        
        let outputStruct = try callDriver(&inputStruct)
        return outputStruct.bytes
    }
    
    private func writeData(_ key: SMCKey, data: SMCBytes) throws {
        var inputStruct = SMCParamStruct()
        inputStruct.key = key.code
        inputStruct.bytes = data
        inputStruct.keyInfo.dataSize = UInt32(key.info.size)
        inputStruct.data8 = SMCParamStruct.Selector.kSMCWriteKey.rawValue
        
        _ = try callDriver(&inputStruct)
    }
    
    private func callDriver(_ inputStruct: inout SMCParamStruct,
                            selector: SMCParamStruct.Selector = .kSMCHandleYPCEvent) throws -> SMCParamStruct {
        var outputStruct = SMCParamStruct()
        let inputStructSize = MemoryLayout<SMCParamStruct>.stride
        var outputStructSize = MemoryLayout<SMCParamStruct>.stride
        
        let result = IOConnectCallStructMethod(connection,
                                               UInt32(selector.rawValue),
                                               &inputStruct,
                                               inputStructSize,
                                               &outputStruct,
                                               &outputStructSize)
        
        switch result {
        case kIOReturnSuccess:
            if outputStruct.result == SMCParamStruct.Result.kSMCSuccess.rawValue {
                return outputStruct
            }
            throw SMCError.unknown(kIOReturn: result, SMCResult: outputStruct.result)
        case kIOReturnNotPrivileged:
            throw SMCError.notPrivileged
        default:
            throw SMCError.unknown(kIOReturn: result, SMCResult: outputStruct.result)
        }
    }
    
    // MARK: - Charge Limit API
    
    /// Read current charge limit value
    /// Returns: 0-100 for Intel, 80 or 100 for Apple Silicon
    public func readChargeLimit() -> Int? {
        do {
            try open()
            defer { close() }
            
            if isAppleSilicon {
                let bytes = try readData(chwaKey)
                // CHWA: 0x01 = 80% limit enabled, 0x00 = disabled (100%)
                return bytes.0 == 0x01 ? 80 : 100
            } else {
                let bytes = try readData(bclmKey)
                return Int(bytes.0)
            }
        } catch {
            print("SMCController: Failed to read charge limit: \(error)")
            return nil
        }
    }
    
    /// Write charge limit value
    /// - Parameter value: 20-100 for Intel, 80 or 100 for Apple Silicon
    public func writeChargeLimit(_ value: Int) -> Bool {
        do {
            try open()
            defer { close() }
            
            if isAppleSilicon {
                // Apple Silicon only supports 80% or 100%
                let enableLimit = value <= 80
                var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                bytes.0 = enableLimit ? 0x01 : 0x00
                try writeData(chwaKey, data: bytes)
            } else {
                // Intel supports 20-100
                let clampedValue = max(20, min(100, value))
                var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                bytes.0 = UInt8(clampedValue)
                try writeData(bclmKey, data: bytes)
            }
            return true
        } catch SMCError.notPrivileged {
            print("SMCController: Root privileges required to write charge limit")
            return false
        } catch {
            print("SMCController: Failed to write charge limit: \(error)")
            return false
        }
    }
    
    /// Check if charge limit feature is available
    public func isChargeLimitAvailable() -> Bool {
        do {
            try open()
            defer { close() }
            
            let key = isAppleSilicon ? chwaKey : bclmKey
            _ = try readData(key)
            return true
        } catch {
            return false
        }
    }
}
