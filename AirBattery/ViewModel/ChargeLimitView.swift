//
//  ChargeLimitView.swift
//  AirBattery
//
//  SwiftUI view for battery charge limit control
//

import SwiftUI

struct ChargeLimitView: View {
    @ObservedObject var manager = ChargeLimitManager.shared
    @State private var sliderValue: Double = 80
    @State private var isEditing = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header row with toggle
            HStack {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)

                Text("Charge Limit")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $manager.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            // Always show slider
            VStack(spacing: 4) {
                HStack {
                    Text("20%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Slider(
                        value: $sliderValue,
                        in: 20...100,
                        step: manager.isAppleSilicon ? 20 : 5,
                        onEditingChanged: { editing in
                            isEditing = editing
                            if !editing {
                                if manager.isAppleSilicon {
                                    sliderValue = sliderValue <= 80 ? 80 : 100
                                }
                                manager.chargeLimit = Int(sliderValue)
                            }
                        }
                    )
                    .accentColor(.green)
                    .disabled(!manager.isEnabled)
                    .opacity(manager.isEnabled ? 1.0 : 0.5)
                    .onAppear {
                        sliderValue = Double(manager.chargeLimit)
                    }
                    .onChange(of: sliderValue) { newValue in
                        if manager.isAppleSilicon {
                            let snapped = newValue <= 90 ? 80.0 : 100.0
                            if sliderValue != snapped {
                                sliderValue = snapped
                            }
                        }
                    }
                    
                    Text("100%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Current value display
                HStack {
                    Text("Stop charging at:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(sliderValue))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(manager.isEnabled ? .green : .secondary)
                    
                    Spacer()
                    
                    if manager.isAppleSilicon {
                        Text("M-chip: 80% or 100%")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    ChargeLimitView()
        .frame(width: 280)
        .padding()
}
