import Foundation
import HomeKit

class HomeAutomationManager: ObservableObject {
    private let homeManager = HMHomeManager()
    
    @Published var availableHomes: [HMHome] = []
    @Published var availableRooms: [HMRoom] = []
    @Published var availableAccessories: [HMAccessory] = []
    @Published var favoriteAccessories: [HMAccessory] = []
    
    // Current selections
    @Published var selectedHome: HMHome?
    @Published var selectedRoom: HMRoom?
    
    init() {
        setupHomeKit()
    }
    
    private func setupHomeKit() {
        // Set up HomeKit notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHomeKitNotification(_:)),
            name: NSNotification.Name.HMHomeManagerDidUpdateHomes,
            object: nil
        )
    }
    
    @objc private func handleHomeKitNotification(_ notification: Notification) {
        // Handle HomeKit notifications to update our data
        updateHomeData()
    }
    
    private func updateHomeData() {
        // Update available homes
        availableHomes = homeManager.homes
        
        // Set first home as selected if none is selected
        if selectedHome == nil && !availableHomes.isEmpty {
            selectedHome = availableHomes.first
        }
        
        // Update rooms and accessories
        if let home = selectedHome {
            availableRooms = home.rooms
            availableAccessories = home.accessories
            
            // Update favorite accessories
            updateFavoriteAccessories()
        }
    }
    
    private func updateFavoriteAccessories() {
        // In a real app, this would filter based on user preferences
        favoriteAccessories = availableAccessories.filter { accessory in
            // For demo, we'll just mark lights and thermostats as favorites
            return accessory.services.contains { service in
                service.serviceType == HMServiceTypeLightbulb ||
                service.serviceType == HMServiceTypeThermostat
            }
        }
    }
    
    func selectHome(home: HMHome) {
        selectedHome = home
        selectedRoom = nil
        updateHomeData()
    }
    
    func selectRoom(room: HMRoom) {
        selectedRoom = room
    }
    
    // MARK: - Device Control
    
    func toggleDevice(_ accessory: HMAccessory, completion: @escaping (Bool) -> Void) {
        // Find the power characteristic
        guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb || $0.serviceType == HMServiceTypeSwitch }),
              let powerCharacteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else {
            completion(false)
            return
        }
        
        // Read current power state
        powerCharacteristic.readValue { error in
            if let error = error {
                print("Error reading power state: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Toggle the power state
            let currentValue = powerCharacteristic.value as? Bool ?? false
            let newValue = !currentValue
            
            powerCharacteristic.writeValue(newValue) { error in
                if let error = error {
                    print("Error toggling device: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    func setDeviceBrightness(_ accessory: HMAccessory, brightness: Int, completion: @escaping (Bool) -> Void) {
        // Find the brightness characteristic
        guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }),
              let brightnessCharacteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeBrightness }) else {
            completion(false)
            return
        }
        
        // Set the brightness (0-100)
        let brightnessValue = min(max(brightness, 0), 100)
        
        brightnessCharacteristic.writeValue(brightnessValue) { error in
            if let error = error {
                print("Error setting brightness: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func setTemperature(_ accessory: HMAccessory, temperature: Double, completion: @escaping (Bool) -> Void) {
        // Find the target temperature characteristic
        guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeThermostat }),
              let temperatureCharacteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeTargetTemperature }) else {
            completion(false)
            return
        }
        
        temperatureCharacteristic.writeValue(temperature) { error in
            if let error = error {
                print("Error setting temperature: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - Voice Command Processing
    
    func processVoiceCommand(_ command: String, completion: @escaping (String) -> Void) {
        // Parse the voice command to determine what the user wants to do
        let lowercasedCommand = command.lowercased()
        
        // Handle light commands
        if lowercasedCommand.contains("light") || lowercasedCommand.contains("lamp") {
            if lowercasedCommand.contains("on") {
                controlLights(turnOn: true) { success in
                    completion(success ? "Lights turned on" : "I couldn't control the lights")
                }
            } else if lowercasedCommand.contains("off") {
                controlLights(turnOn: false) { success in
                    completion(success ? "Lights turned off" : "I couldn't control the lights")
                }
            } else if lowercasedCommand.contains("bright") {
                let brightness = extractNumber(from: lowercasedCommand) ?? 100
                setLightsBrightness(brightness) { success in
                    completion(success ? "Brightness set to \(brightness)%" : "I couldn't adjust the brightness")
                }
            } else {
                completion("Would you like to turn the lights on or off?")
            }
        }
        // Handle thermostat commands
        else if lowercasedCommand.contains("temperature") || lowercasedCommand.contains("thermostat") {
            if let temperature = extractNumber(from: lowercasedCommand) {
                setThermostat(temperature: Double(temperature)) { success in
                    completion(success ? "Temperature set to \(temperature) degrees" : "I couldn't adjust the temperature")
                }
            } else {
                completion("What temperature would you like to set?")
            }
        }
        // Handle room-specific commands
        else if let room = availableRooms.first(where: { lowercasedCommand.contains($0.name.lowercased()) }) {
            selectedRoom = room
            completion("Selected the \(room.name). What would you like to control?")
        }
        // Generic control command
        else if lowercasedCommand.contains("turn on") || lowercasedCommand.contains("turn off") {
            let turnOn = lowercasedCommand.contains("turn on")
            controlDevices(turnOn: turnOn) { success in
                completion(success ? "Devices turned \(turnOn ? "on" : "off")" : "I couldn't control those devices")
            }
        }
        // Handle unknown commands
        else {
            completion("I can help you control lights, adjust temperature, or manage other smart devices. What would you like to do?")
        }
    }
    
    private func controlLights(turnOn: Bool, completion: @escaping (Bool) -> Void) {
        // Filter for light accessories
        let lightAccessories = getAccessoriesInScope().filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        if lightAccessories.isEmpty {
            completion(false)
            return
        }
        
        // Create a dispatch group to track multiple operations
        let dispatchGroup = DispatchGroup()
        var overallSuccess = true
        
        for accessory in lightAccessories {
            dispatchGroup.enter()
            
            // Find the power characteristic
            guard let service = accessory.services.first(where: { $0.serviceType == HMServiceTypeLightbulb }),
                  let powerCharacteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else {
                dispatchGroup.leave()
                continue
            }
            
            // Set the power state
            powerCharacteristic.writeValue(turnOn) { error in
                if let error = error {
                    print("Error controlling \(accessory.name): \(error.localizedDescription)")
                    overallSuccess = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
    
    private func setLightsBrightness(_ brightness: Int, completion: @escaping (Bool) -> Void) {
        // Filter for light accessories
        let lightAccessories = getAccessoriesInScope().filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeLightbulb }
        }
        
        if lightAccessories.isEmpty {
            completion(false)
            return
        }
        
        // Create a dispatch group to track multiple operations
        let dispatchGroup = DispatchGroup()
        var overallSuccess = true
        
        for accessory in lightAccessories {
            dispatchGroup.enter()
            
            setDeviceBrightness(accessory, brightness: brightness) { success in
                if !success {
                    overallSuccess = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
    
    private func setThermostat(temperature: Double, completion: @escaping (Bool) -> Void) {
        // Filter for thermostat accessories
        let thermostatAccessories = getAccessoriesInScope().filter { accessory in
            accessory.services.contains { $0.serviceType == HMServiceTypeThermostat }
        }
        
        if thermostatAccessories.isEmpty {
            completion(false)
            return
        }
        
        // Create a dispatch group to track multiple operations
        let dispatchGroup = DispatchGroup()
        var overallSuccess = true
        
        for accessory in thermostatAccessories {
            dispatchGroup.enter()
            
            setTemperature(accessory, temperature: temperature) { success in
                if !success {
                    overallSuccess = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
    
    private func controlDevices(turnOn: Bool, completion: @escaping (Bool) -> Void) {
        // Get accessories that can be turned on/off
        let controllableAccessories = getAccessoriesInScope().filter { accessory in
            accessory.services.contains { service in
                service.characteristics.contains { characteristic in
                    characteristic.characteristicType == HMCharacteristicTypePowerState
                }
            }
        }
        
        if controllableAccessories.isEmpty {
            completion(false)
            return
        }
        
        // Create a dispatch group to track multiple operations
        let dispatchGroup = DispatchGroup()
        var overallSuccess = true
        
        for accessory in controllableAccessories {
            dispatchGroup.enter()
            
            // Find services with power characteristics
            for service in accessory.services {
                guard let powerCharacteristic = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else {
                    continue
                }
                
                // Set the power state
                powerCharacteristic.writeValue(turnOn) { error in
                    if let error = error {
                        print("Error controlling \(accessory.name): \(error.localizedDescription)")
                        overallSuccess = false
                    }
                    dispatchGroup.leave()
                }
                
                break
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
    
    // MARK: - Helper methods
    
    private func getAccessoriesInScope() -> [HMAccessory] {
        // If a room is selected, return accessories in that room
        if let room = selectedRoom {
            return availableAccessories.filter { $0.room?.uniqueIdentifier == room.uniqueIdentifier }
        }
        
        // Otherwise return all accessories
        return availableAccessories
    }
    
    private func extractNumber(from text: String) -> Int? {
        // Extract a number from a string like "set brightness to 50 percent"
        let pattern = "\\b\\d+\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let matches = regex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              let match = matches.first,
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        return Int(text[range])
    }
}
