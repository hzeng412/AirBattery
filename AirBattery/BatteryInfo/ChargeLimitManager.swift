//
//  ChargeLimitManager.swift
//  AirBattery
//
//  Manages battery charge limit settings and persistence
//

import Foundation
import Combine

/// Manages battery charge limit feature
public class ChargeLimitManager: ObservableObject {
    
    public static let shared = ChargeLimitManager()
    
    // MARK: - Published Properties
    
    /// Whether the charge limit feature is enabled
    @Published public var isEnabled: Bool {
        didSet {
            guard !_suppressApply else { return }
            UserDefaults.standard.set(isEnabled, forKey: "chargeLimitEnabled")
            applyChargeLimit()
        }
    }

    /// The target charge limit percentage (20-100 for Intel, 80 or 100 for Apple Silicon)
    @Published public var chargeLimit: Int {
        didSet {
            guard !_suppressApply else { return }
            UserDefaults.standard.set(chargeLimit, forKey: "chargeLimitValue")
            applyChargeLimit()
        }
    }
    
    /// Whether the feature is available on this Mac
    @Published public var isAvailable: Bool = false
    
    /// Whether running on Apple Silicon (limited to 80/100 only)
    @Published public var isAppleSilicon: Bool = false
    
    /// Current SMC charge limit value (read from hardware)
    @Published public var currentSMCValue: Int?
    
    // MARK: - Private Properties

    private let smcController = SMCController.shared
    private var refreshTimer: Timer?
    private var _suppressApply = false
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preferences (suppress didSet during init)
        _suppressApply = true
        self.isEnabled = UserDefaults.standard.bool(forKey: "chargeLimitEnabled")
        self.chargeLimit = UserDefaults.standard.integer(forKey: "chargeLimitValue")

        // Default to 80% if not set
        if chargeLimit == 0 {
            chargeLimit = 80
        }
        _suppressApply = false

        // Check hardware capabilities
        self.isAppleSilicon = smcController.isAppleSilicon

        // Always show UI on Macs with batteries - users can try enabling
        // The actual SMC access may fail but the UI should still be visible
        self.isAvailable = true

        // Try to read current value (may fail on some systems)
        refreshCurrentValue()

        // Apply saved limit on startup if enabled
        if isEnabled {
            applyChargeLimit()
        }

        // Set up periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshCurrentValue()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Refresh the current SMC charge limit value
    public func refreshCurrentValue() {
        currentSMCValue = smcController.readChargeLimit()
    }
    
    /// Whether a privileged write is currently in progress
    @Published public var isWriting: Bool = false

    /// Apply the current charge limit setting to SMC via privileged helper
    public func applyChargeLimit() {
        let key: String
        let value: Int

        if isEnabled {
            if isAppleSilicon {
                key = "CHWA"
                value = chargeLimit <= 80 ? 1 : 0
            } else {
                key = "BCLM"
                value = max(20, min(100, chargeLimit))
            }
        } else {
            if isAppleSilicon {
                key = "CHWA"
                value = 0
            } else {
                key = "BCLM"
                value = 100
            }
        }

        writeWithPrivilege(key: key, value: value)
    }

    /// Reset charge limit to default (100%, disabled)
    public func resetToDefault() {
        isEnabled = false
        chargeLimit = 80
        let key = isAppleSilicon ? "CHWA" : "BCLM"
        let value = isAppleSilicon ? 0 : 100
        writeWithPrivilege(key: key, value: value)
    }

    // MARK: - Privileged Write

    /// Write an SMC key via the bundled smc-write helper with admin privileges.
    /// Runs on a background queue; updates UI on main queue.
    private func writeWithPrivilege(key: String, value: Int) {
        guard let toolPath = Bundle.main.path(forResource: "smc-write", ofType: nil) else {
            print("ChargeLimitManager: smc-write tool not found in bundle")
            return
        }

        DispatchQueue.main.async { self.isWriting = true }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let command = "'\(toolPath)' \(key) \(value)"
            let result = CommandLineTool.runAsRoot(command)

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isWriting = false

                if result.success {
                    self.refreshCurrentValue()
                } else {
                    // User cancelled or write failed — revert state
                    self.revertState()
                }
            }
        }
    }

    /// Revert published state to match what's actually in SMC
    private func revertState() {
        refreshCurrentValue()
        if let current = currentSMCValue {
            let wasEnabled: Bool
            if isAppleSilicon {
                wasEnabled = current == 80
            } else {
                wasEnabled = current < 100
            }
            // Suppress didSet side-effects during revert
            let savedEnabled = wasEnabled
            let savedLimit = isAppleSilicon ? (wasEnabled ? 80 : 100) : current
            UserDefaults.standard.set(savedEnabled, forKey: "chargeLimitEnabled")
            UserDefaults.standard.set(savedLimit, forKey: "chargeLimitValue")

            // Use internal storage to avoid re-triggering applyChargeLimit
            _suppressApply = true
            isEnabled = savedEnabled
            chargeLimit = savedLimit
            _suppressApply = false
        }
    }
    
    /// Get available charge limit options for this Mac
    public var availableOptions: [Int] {
        if isAppleSilicon {
            return [80, 100]
        } else {
            return Array(stride(from: 20, through: 100, by: 5))
        }
    }
    
    /// Human-readable description of current state
    public var statusDescription: String {
        if !isAvailable {
            return "Not available on this Mac"
        }
        
        if !isEnabled {
            return "Charge limit disabled"
        }
        
        if let current = currentSMCValue {
            return "Limit set to \(current)%"
        }
        
        return "Limit set to \(chargeLimit)%"
    }
}
