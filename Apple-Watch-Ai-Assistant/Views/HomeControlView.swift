import SwiftUI
import HomeKit

struct HomeControlView: View {
    @EnvironmentObject var homeAutomationManager: HomeAutomationManager
    @State private var selectedDeviceType: DeviceType = .lights
    
    enum DeviceType: String, CaseIterable {
        case lights = "Lights"
        case thermostats = "Climate"
        case locks = "Locks"
        case all = "All"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Device type picker
                Picker("Device Type", selection: $selectedDeviceType) {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Room selection
                if !homeAutomationManager.availableRooms.isEmpty {
                    roomSelectionView
                }
                
                // Device controls
                deviceListView
                
                // Quick actions
                quickActionsView
            }
            .padding(.vertical)
        }
    }
    
    private var roomSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button(action: {
                    // Clear room selection to show all devices
                    homeAutomationManager.selectRoom(room: nil)
                }) {
                    Text("All Rooms")
                        .font(.system(.caption, design: .rounded))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(homeAutomationManager.selectedRoom == nil ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(homeAutomationManager.selectedRoom == nil ? .white : .primary)
                        .cornerRadius(16)
                }
                
                ForEach(homeAutomationManager.availableRooms, id: \.uniqueIdentifier) { room in
                    Button(action: {
                        homeAutomationManager.selectRoom(room: room)
                    }) {
                        Text(room.name)
                            .font(.system(.caption, design: .rounded))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(room.uniqueIdentifier == homeAutomationManager.selectedRoom?.uniqueIdentifier ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(room.uniqueIdentifier == homeAutomationManager.selectedRoom?.uniqueIdentifier ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var deviceListView: some View {
        VStack(spacing: 8) {
            if filteredDevices.isEmpty {
                Text("No \(selectedDeviceType.rawValue) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(filteredDevices, id: \.uniqueIdentifier) { accessory in
                    DeviceControlRow(accessory: accessory)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var quickActionsView: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                // Control all lights
                Button(action: {
                    controlAllLights(turnOn: true)
                }) {
                    VStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.yellow)
                            .clipShape(Circle())
                        
                        Text("All Lights On")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Control all lights off
                Button(action: {
                    controlAllLights(turnOn: false)
                }) {
                    VStack {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.gray)
                            .clipShape(Circle())
                        
                        Text("All Lights Off")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Night mode
                Button(action: {
                    setNightMode()
                }) {
                    VStack {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.indigo)
                            .clipShape(Circle())
                        
                        Text("Night Mode")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
    
    // Filtered devices based on selected type
    private var filteredDevices: [HMAccessory] {
        let accessories = homeAutomationManager.availableAccessories
        
        switch selectedDeviceType {
        case .lights:
            return accessories.filter { accessory in
                accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
            }
        case .thermostats:
            return accessories.filter { accessory in
                accessory.services.contains { $0.serviceType == HMServiceTypeThermostat }
            }
        case .locks:
            return accessories.filter { accessory in
                accessory.services.contains { $0.serviceType == HMServiceTypeSecurableLock }
            }
        case .all:
            return accessories
        }
    }
    
    // Control all lights
    private func controlAllLights(turnOn: Bool) {
        // In a real app, this would use homeAutomationManager to control all lights
        print("Setting all lights to \(turnOn ? "on" : "off")")
        
        let lightAccessories = homeAutomationManager.availableAccessories.filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        for accessory in lightAccessories {
            homeAutomationManager.toggleDevice(accessory) { _ in
                // Handle success/failure
            }
        }
    }
    
    // Set night mode (dim lights, lower temperature)
    private func setNightMode() {
        // In a real app, this would dim lights and adjust temperature
        print("Setting night mode")
        
        // Dim all lights to 20%
        let lightAccessories = homeAutomationManager.availableAccessories.filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        for accessory in lightAccessories {
            homeAutomationManager.setDeviceBrightness(accessory, brightness: 20) { _ in
                // Handle success/failure
            }
        }
        
        // Set thermostat to comfortable sleeping temperature (68°F/20°C)
        let thermostatAccessories = homeAutomationManager.availableAccessories.filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeThermostat }
        }
        
        for accessory in thermostatAccessories {
            homeAutomationManager.setTemperature(accessory, temperature: 20.0) { _ in
                // Handle success/failure
            }
        }
    }
}

struct DeviceControlRow: View {
    let accessory: HMAccessory
    @State private var isOn = false
    @State private var brightness: Double = 100
    @State private var temperature: Double = 22.0
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Main device control
            Button(action: {
                showDetails.toggle()
            }) {
                HStack {
                    // Device icon
                    Image(systemName: deviceIcon)
                        .font(.system(size: 18))
                        .foregroundColor(deviceIconColor)
                        .frame(width: 36, height: 36)
                        .background(deviceBackgroundColor)
                        .clipShape(Circle())
                    
                    // Device name and status
                    VStack(alignment: .leading) {
                        Text(accessory.name)
                            .font(.system(.body, design: .rounded))
                        
                        Text(deviceStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle switch for direct control
                    if isLightOrSwitch {
                        Toggle("", isOn: $isOn)
                            .labelsHidden()
                            .onChange(of: isOn) { newValue in
                                toggleDevice()
                            }
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details
            if showDetails {
                VStack(spacing: 16) {
                    // Light brightness slider
                    if isLight {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Brightness")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "sun.min")
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $brightness, in: 0...100, step: 1)
                                    .onChange(of: brightness) { newValue in
                                        updateBrightness()
                                    }
                                
                                Image(systemName: "sun.max")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Thermostat control
                    if isThermostat {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperature")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "thermometer.snowflake")
                                    .foregroundColor(.blue)
                                
                                Slider(value: $temperature, in: 15...30, step: 0.5)
                                    .onChange(of: temperature) { newValue in
                                        updateTemperature()
                                    }
                                
                                Image(systemName: "thermometer.sun")
                                    .foregroundColor(.orange)
                            }
                            
                            Text("\(temperature, specifier: "%.1f")°C")
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
            }
        }
    }
    
    // Device properties
    private var isLight: Bool {
        accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
    }
    
    private var isSwitch: Bool {
        accessory.services.contains { $0.serviceType == HMServiceTypeSwitch }
    }
    
    private var isThermostat: Bool {
        accessory.services.contains { $0.serviceType == HMServiceTypeThermostat }
    }
    
    private var isLock: Bool {
        accessory.services.contains { $0.serviceType == HMServiceTypeSecurableLock }
    }
    
    private var isLightOrSwitch: Bool {
        isLight || isSwitch
    }
    
    // UI helpers
    private var deviceIcon: String {
        if isLight {
            return isOn ? "lightbulb.fill" : "lightbulb"
        } else if isSwitch {
            return isOn ? "poweron" : "poweroff"
        } else if isThermostat {
            return "thermometer"
        } else if isLock {
            return isOn ? "lock.open" : "lock"
        } else {
            return "app.connected.to.app.below.fill"
        }
    }
    
    private var deviceIconColor: Color {
        isOn ? .white : .gray
    }
    
    private var deviceBackgroundColor: Color {
        if isOn {
            if isLight {
                return .yellow
            } else if isThermostat {
                return .orange
            } else if isLock {
                return .green
            } else {
                return .blue
            }
        } else {
            return .gray
        }
    }
    
    private var deviceStatus: String {
        if isLight {
            return isOn ? "On - \(Int(brightness))%" : "Off"
        } else if isThermostat {
            return "\(temperature, specifier: "%.1f")°C"
        } else if isLock {
            return isOn ? "Unlocked" : "Locked"
        } else {
            return isOn ? "On" : "Off"
        }
    }
    
    // Device control methods
    private func toggleDevice() {
        // In a real app, this would use HomeKit to toggle the device
        print("Toggling \(accessory.name) to \(isOn ? "on" : "off")")
    }
    
    private func updateBrightness() {
        // In a real app, this would use HomeKit to adjust brightness
        print("Setting \(accessory.name) brightness to \(Int(brightness))%")
    }
    
    private func updateTemperature() {
        // In a real app, this would use HomeKit to adjust temperature
        print("Setting \(accessory.name) temperature to \(temperature)°C")
    }
}
