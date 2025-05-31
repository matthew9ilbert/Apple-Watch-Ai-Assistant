import Foundation
import CoreLocation
import WeatherKit
import Charts

@MainActor
class WeatherManager: NSObject, ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourWeather] = []
    @Published var dailyForecast: [DayWeather] = []
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private let notificationManager = NotificationManager.shared
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Location Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Weather Data
    
    struct CurrentWeather {
        let temperature: Double
        let condition: WeatherCondition
        let humidity: Double
        let windSpeed: Double
        let windDirection: Double
        let pressure: Double
        let visibility: Double
        let uvIndex: Int
        let feelsLike: Double
        
        var formattedTemperature: String {
            return String(format: "%.1f°", temperature)
        }
        
        var formattedWindSpeed: String {
            return String(format: "%.1f mph", windSpeed)
        }
        
        var formattedHumidity: String {
            return String(format: "%.0f%%", humidity * 100)
        }
    }
    
    struct HourWeather: Identifiable {
        let id = UUID()
        let date: Date
        let temperature: Double
        let condition: WeatherCondition
        let precipitation: Double
        let windSpeed: Double
        
        var hour: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            return formatter.string(from: date)
        }
    }
    
    struct DayWeather: Identifiable {
        let id = UUID()
        let date: Date
        let high: Double
        let low: Double
        let condition: WeatherCondition
        let precipitationChance: Double
        let sunrise: Date
        let sunset: Date
        
        var dayName: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    struct WeatherAlert: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let severity: Severity
        let startTime: Date
        let endTime: Date
        
        enum Severity: String {
            case extreme
            case severe
            case moderate
            case minor
        }
    }
    
    enum WeatherCondition: String {
        case clear = "Clear"
        case partlyCloudy = "Partly Cloudy"
        case cloudy = "Cloudy"
        case rain = "Rain"
        case snow = "Snow"
        case sleet = "Sleet"
        case fog = "Fog"
        case thunderstorm = "Thunderstorm"
        case windy = "Windy"
        
        var systemImageName: String {
            switch self {
            case .clear:
                return "sun.max.fill"
            case .partlyCloudy:
                return "cloud.sun.fill"
            case .cloudy:
                return "cloud.fill"
            case .rain:
                return "cloud.rain.fill"
            case .snow:
                return "cloud.snow.fill"
            case .sleet:
                return "cloud.sleet.fill"
            case .fog:
                return "cloud.fog.fill"
            case .thunderstorm:
                return "cloud.bolt.rain.fill"
            case .windy:
                return "wind"
            }
        }
    }
    
    // MARK: - Weather Fetching
    
    func fetchWeather() async {
        guard let location = currentLocation else {
            errorMessage = "Location not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            
            // Update current weather
            updateCurrentWeather(from: weather)
            
            // Update forecasts
            await updateHourlyForecast(from: weather)
            await updateDailyForecast(from: weather)
            
            // Check for weather alerts
            await checkWeatherAlerts(from: weather)
            
            lastUpdated = Date()
            isLoading = false
        } catch {
            errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func updateCurrentWeather(from weather: Weather) {
        let current = CurrentWeather(
            temperature: weather.currentWeather.temperature.value,
            condition: mapWeatherCondition(weather.currentWeather.condition),
            humidity: weather.currentWeather.humidity,
            windSpeed: weather.currentWeather.wind.speed.value,
            windDirection: weather.currentWeather.wind.direction.value,
            pressure: weather.currentWeather.pressure.value,
            visibility: weather.currentWeather.visibility.value,
            uvIndex: weather.currentWeather.uvIndex.value,
            feelsLike: weather.currentWeather.apparentTemperature.value
        )
        
        self.currentWeather = current
    }
    
    private func updateHourlyForecast(from weather: Weather) async {
        let hourlyForecast = weather.hourlyForecast.forecast.prefix(24).map { hour in
            HourWeather(
                date: hour.date,
                temperature: hour.temperature.value,
                condition: mapWeatherCondition(hour.condition),
                precipitation: hour.precipitationChance,
                windSpeed: hour.wind.speed.value
            )
        }
        
        self.hourlyForecast = hourlyForecast
    }
    
    private func updateDailyForecast(from weather: Weather) async {
        let dailyForecast = weather.dailyForecast.forecast.prefix(7).map { day in
            DayWeather(
                date: day.date,
                high: day.highTemperature.value,
                low: day.lowTemperature.value,
                condition: mapWeatherCondition(day.condition),
                precipitationChance: day.precipitationChance,
                sunrise: day.sun.sunrise!,
                sunset: day.sun.sunset!
            )
        }
        
        self.dailyForecast = dailyForecast
    }
    
    private func checkWeatherAlerts(from weather: Weather) async {
        let alerts = weather.weatherAlerts?.map { alert in
            WeatherAlert(
                title: alert.summary,
                description: alert.detailedDescription,
                severity: mapAlertSeverity(alert.severity),
                startTime: alert.effectiveTime,
                endTime: alert.expirationTime
            )
        } ?? []
        
        self.weatherAlerts = alerts
        
        // Send notifications for new alerts
        for alert in alerts {
            notificationManager.scheduleWeatherAlert(
                condition: .extreme,
                message: alert.description
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func mapWeatherCondition(_ condition: WeatherCondition) -> WeatherCondition {
        switch condition.rawValue.lowercased() {
        case _ where condition.rawValue.contains("clear"):
            return .clear
        case _ where condition.rawValue.contains("partly cloudy"):
            return .partlyCloudy
        case _ where condition.rawValue.contains("cloudy"):
            return .cloudy
        case _ where condition.rawValue.contains("rain"):
            return .rain
        case _ where condition.rawValue.contains("snow"):
            return .snow
        case _ where condition.rawValue.contains("sleet"):
            return .sleet
        case _ where condition.rawValue.contains("fog"):
            return .fog
        case _ where condition.rawValue.contains("thunderstorm"):
            return .thunderstorm
        case _ where condition.rawValue.contains("wind"):
            return .windy
        default:
            return .clear
        }
    }
    
    private func mapAlertSeverity(_ severity: WeatherSeverity) -> WeatherAlert.Severity {
        switch severity {
        case .extreme:
            return .extreme
        case .severe:
            return .severe
        case .moderate:
            return .moderate
        default:
            return .minor
        }
    }
    
    // MARK: - Weather Analysis
    
    func shouldSuggestIndoorWorkout() -> Bool {
        guard let currentWeather = currentWeather else { return false }
        
        // Check for adverse weather conditions
        let adverseConditions: [WeatherCondition] = [.rain, .snow, .thunderstorm]
        if adverseConditions.contains(currentWeather.condition) {
            return true
        }
        
        // Check for extreme temperatures
        if currentWeather.temperature > 95 || currentWeather.temperature < 32 {
            return true
        }
        
        // Check for high UV index
        if currentWeather.uvIndex > 8 {
            return true
        }
        
        return false
    }
    
    func getClothingRecommendations() -> [String] {
        guard let currentWeather = currentWeather else { return [] }
        
        var recommendations: [String] = []
        
        // Temperature-based recommendations
        if currentWeather.temperature < 32 {
            recommendations.append("Heavy winter coat")
            recommendations.append("Gloves and hat")
        } else if currentWeather.temperature < 50 {
            recommendations.append("Light jacket or sweater")
        } else if currentWeather.temperature > 80 {
            recommendations.append("Light, breathable clothing")
        }
        
        // Condition-based recommendations
        switch currentWeather.condition {
        case .rain:
            recommendations.append("Rain jacket")
            recommendations.append("Waterproof shoes")
        case .snow:
            recommendations.append("Snow boots")
            recommendations.append("Waterproof outerwear")
        case .windy:
            recommendations.append("Windbreaker")
        default:
            break
        }
        
        // UV protection
        if currentWeather.uvIndex > 5 {
            recommendations.append("Sunscreen")
            recommendations.append("Sunglasses")
            recommendations.append("Hat with brim")
        }
        
        return recommendations
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        Task {
            await fetchWeather()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location error: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied"
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
