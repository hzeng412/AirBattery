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
            UserDefaults.standard.set(isEnabled, forKey: "chargeLimitEnabled")
            applyChargeLimit()
        }
    }
    
    /// The target charge limit percentage (20-100 for Intel, 80 or 100 for Apple Silicon)
    @Published public var chargeLimit: Int {
        didSet {
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
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preferences
        self.isEnabled = UserDefaults.standard.bool(forKey: "chargeLimitEnabled")
        self.chargeLimit = UserDefaults.standard.integer(forKey: "chargeLimitValue")
        
        // Default to 80% if not set
        if chargeLimit == 0 {
            chargeLimit = 80
        }
        
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
    
    /// Apply the current charge limit setting to SMC
    public func applyChargeLimit() {
        if isEnabled {
            let targetValue = isAppleSilicon ? (chargeLimit <= 80 ? 80 : 100) : chargeLimit
            let success = smcController.writeChargeLimit(targetValue)
            if success {
                refreshCurrentValue()
            }
        } else {
            // Disable limit by setting to 100%
            let success = smcController.writeChargeLimit(100)
            if success {
                refreshCurrentValue()
            }
        }
    }
    
    /// Reset charge limit to default (100%, disabled)
    public func resetToDefault() {
        isEnabled = false
        chargeLimit = 80
        _ = smcController.writeChargeLimit(100)
        refreshCurrentValue()
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
