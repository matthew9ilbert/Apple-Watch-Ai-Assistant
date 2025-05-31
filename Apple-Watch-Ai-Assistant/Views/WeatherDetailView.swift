import SwiftUI
import Charts

struct WeatherDetailView: View {
    @EnvironmentObject var weatherManager: WeatherManager
    @State private var selectedTimeRange: TimeRange = .hourly
    @State private var showingAlerts = false
    
    enum TimeRange {
        case hourly
        case daily
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current weather card
                currentWeatherCard
                
                // Forecast selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("Hourly").tag(TimeRange.hourly)
                    Text("Daily").tag(TimeRange.daily)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Forecast view
                if selectedTimeRange == .hourly {
                    hourlyForecastView
                } else {
                    dailyForecastView
                }
                
                // Additional weather details
                weatherDetailsCard
                
                // Weather alerts
                if !weatherManager.weatherAlerts.isEmpty {
                    alertsSection
                }
                
                // Weather-based recommendations
                recommendationsCard
            }
            .padding(.vertical)
        }
        .navigationTitle("Weather")
        .sheet(isPresented: $showingAlerts) {
            WeatherAlertsView(alerts: weatherManager.weatherAlerts)
        }
    }
    
    // MARK: - Current Weather Card
    
    private var currentWeatherCard: some View {
        VStack(spacing: 12) {
            // Temperature and condition
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(weatherManager.currentWeather?.formattedTemperature ?? "--°")
                        .font(.system(size: 48, weight: .bold))
                    
                    Text("Feels like \(weatherManager.currentWeather?.feelsLike.formatted() ?? "--")°")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: weatherManager.currentWeather?.condition.systemImageName ?? "cloud.fill")
                        .font(.system(size: 40))
                    
                    Text(weatherManager.currentWeather?.condition.rawValue ?? "--")
                        .font(.caption)
                }
            }
            
            Divider()
            
            // Quick metrics
            HStack {
                WeatherMetric(
                    icon: "wind",
                    value: weatherManager.currentWeather?.formattedWindSpeed ?? "--",
                    label: "Wind"
                )
                
                Divider()
                
                WeatherMetric(
                    icon: "humidity",
                    value: weatherManager.currentWeather?.formattedHumidity ?? "--",
                    label: "Humidity"
                )
                
                Divider()
                
                WeatherMetric(
                    icon: "sun.max.fill",
                    value: "\(weatherManager.currentWeather?.uvIndex ?? 0)",
                    label: "UV Index"
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Hourly Forecast
    
    private var hourlyForecastView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24-Hour Forecast")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(weatherManager.hourlyForecast) { hour in
                        VStack(spacing: 8) {
                            Text(hour.hour)
                                .font(.caption)
                            
                            Image(systemName: hour.condition.systemImageName)
                                .font(.title3)
                            
                            Text(String(format: "%.0f°", hour.temperature))
                                .font(.callout)
                            
                            if hour.precipitation > 0 {
                                Text("\(Int(hour.precipitation * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal)
            }
            
            // Temperature chart
            Chart {
                ForEach(weatherManager.hourlyForecast) { hour in
                    LineMark(
                        x: .value("Time", hour.hour),
                        y: .value("Temperature", hour.temperature)
                    )
                    .foregroundStyle(Color.orange.gradient)
                }
            }
            .frame(height: 100)
            .padding()
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Daily Forecast
    
    private var dailyForecastView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Forecast")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(weatherManager.dailyForecast) { day in
                HStack {
                    Text(day.dayName)
                        .frame(width: 100, alignment: .leading)
                    
                    Image(systemName: day.condition.systemImageName)
                        .frame(width: 30)
                    
                    Text(String(format: "%.0f°", day.high))
                        .frame(width: 50)
                        .foregroundColor(.red)
                    
                    Text(String(format: "%.0f°", day.low))
                        .frame(width: 50)
                        .foregroundColor(.blue)
                    
                    if day.precipitationChance > 0 {
                        Text("\(Int(day.precipitationChance * 100))%")
                            .frame(width: 50)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
                
                if day != weatherManager.dailyForecast.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Weather Details Card
    
    private var weatherDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    DetailRow(icon: "thermometer", label: "High", value: highTemp)
                    DetailRow(icon: "thermometer", label: "Low", value: lowTemp)
                }
                
                GridRow {
                    DetailRow(icon: "sunrise", label: "Sunrise", value: sunrise)
                    DetailRow(icon: "sunset", label: "Sunset", value: sunset)
                }
                
                GridRow {
                    DetailRow(icon: "wind", label: "Wind Speed", value: windSpeed)
                    DetailRow(icon: "arrow.up", label: "Wind Direction", value: windDirection)
                }
                
                GridRow {
                    DetailRow(icon: "humidity", label: "Humidity", value: humidity)
                    DetailRow(icon: "gauge", label: "Pressure", value: pressure)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showingAlerts = true
            }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(weatherManager.weatherAlerts.count) Weather Alert(s)")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Recommendations Card
    
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
            
            ForEach(weatherManager.getClothingRecommendations(), id: \.self) { recommendation in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(recommendation)
                }
            }
            
            if weatherManager.shouldSuggestIndoorWorkout() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Indoor workout recommended")
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Supporting Views
    
    struct WeatherMetric: View {
        let icon: String
        let value: String
        let label: String
        
        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(value)
                    .font(.subheadline)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    struct DetailRow: View {
        let icon: String
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                VStack(alignment: .leading) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Weather Alerts View

struct WeatherAlertsView: View {
    let alerts: [WeatherManager.WeatherAlert]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(alerts) { alert in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(alertColor(for: alert.severity))
                        Text(alert.title)
                            .font(.headline)
                    }
                    
                    Text(alert.description)
                        .font(.subheadline)
                    
                    Text("Valid until: \(alert.endTime.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func alertColor(for severity: WeatherManager.WeatherAlert.Severity) -> Color {
        switch severity {
        case .extreme:
            return .red
        case .severe:
            return .orange
        case .moderate:
            return .yellow
        case .minor:
            return .blue
        }
    }
}

// MARK: - Helper Extensions

private extension WeatherDetailView {
    var highTemp: String {
        guard let high = weatherManager.dailyForecast.first?.high else { return "--" }
        return String(format: "%.0f°", high)
    }
    
    var lowTemp: String {
        guard let low = weatherManager.dailyForecast.first?.low else { return "--" }
        return String(format: "%.0f°", low)
    }
    
    var sunrise: String {
        guard let sunrise = weatherManager.dailyForecast.first?.sunrise else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: sunrise)
    }
    
    var sunset: String {
        guard let sunset = weatherManager.dailyForecast.first?.sunset else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: sunset)
    }
    
    var windSpeed: String {
        weatherManager.currentWeather?.formattedWindSpeed ?? "--"
    }
    
    var windDirection: String {
        guard let direction = weatherManager.currentWeather?.windDirection else { return "--" }
        return String(format: "%.0f°", direction)
    }
    
    var humidity: String {
        weatherManager.currentWeather?.formattedHumidity ?? "--"
    }
    
    var pressure: String {
        guard let pressure = weatherManager.currentWeather?.pressure else { return "--" }
        return String(format: "%.0f hPa", pressure)
    }
}
