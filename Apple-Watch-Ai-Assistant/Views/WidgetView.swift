import SwiftUI
import HealthKit
import WeatherKit

struct WidgetView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var reminderManager: ReminderManager
    
    @State private var selectedWidget: WidgetType = .health
    @State private var showingDetail = false
    
    enum WidgetType {
        case health
        case weather
        case activity
        case reminders
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Widget selector
                widgetPicker
                
                // Selected widget view
                selectedWidgetView
                
                // Quick actions
                quickActionsGrid
            }
            .padding()
        }
    }
    
    // MARK: - Widget Picker
    
    private var widgetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                widgetButton(.health, "heart.fill", "Health")
                widgetButton(.weather, "cloud.sun.fill", "Weather")
                widgetButton(.activity, "figure.run", "Activity")
                widgetButton(.reminders, "list.bullet", "Reminders")
            }
            .padding(.horizontal)
        }
    }
    
    private func widgetButton(_ type: WidgetType, _ icon: String, _ title: String) -> some View {
        Button(action: {
            withAnimation {
                selectedWidget = type
            }
        }) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 70, height: 70)
            .background(selectedWidget == type ? Color.blue : Color(UIColor.systemGray5))
            .foregroundColor(selectedWidget == type ? .white : .primary)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Selected Widget View
    
    @ViewBuilder
    private var selectedWidgetView: some View {
        switch selectedWidget {
        case .health:
            HealthWidget()
        case .weather:
            WeatherWidget()
        case .activity:
            ActivityWidget()
        case .reminders:
            ReminderWidget()
        }
    }
    
    // MARK: - Quick Actions Grid
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickActionButton(
                title: "Start Workout",
                icon: "figure.run",
                color: .green
            ) {
                // Handle workout action
            }
            
            QuickActionButton(
                title: "New Reminder",
                icon: "calendar.badge.plus",
                color: .orange
            ) {
                // Handle reminder action
            }
            
            QuickActionButton(
                title: "Message",
                icon: "message.fill",
                color: .blue
            ) {
                // Handle message action
            }
            
            QuickActionButton(
                title: "Voice Command",
                icon: "waveform",
                color: .purple
            ) {
                // Handle voice command
            }
        }
    }
}

// MARK: - Widget Views

struct HealthWidget: View {
    @EnvironmentObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Overview")
                    .font(.headline)
                Spacer()
                Button("Details") {
                    // Show health details
                }
                .font(.caption)
            }
            
            HStack(spacing: 20) {
                MetricView(
                    value: "\(healthManager.currentHeartRate ?? 0)",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
                
                MetricView(
                    value: "\(healthManager.stepCount)",
                    unit: "Steps",
                    icon: "figure.walk",
                    color: .green
                )
                
                MetricView(
                    value: "\(Int(healthManager.activeCalories))",
                    unit: "Cal",
                    icon: "flame.fill",
                    color: .orange
                )
            }
            
            if let tip = healthManager.healthTips.first {
                Text(tip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

struct WeatherWidget: View {
    @EnvironmentObject var weatherManager: WeatherManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Weather")
                    .font(.headline)
                Spacer()
                Button("Forecast") {
                    // Show weather details
                }
                .font(.caption)
            }
            
            if let weather = weatherManager.currentWeather {
                HStack(spacing: 20) {
                    // Temperature
                    VStack {
                        Text(weather.formattedTemperature)
                            .font(.title)
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Condition
                    VStack {
                        Image(systemName: weather.condition.systemImageName)
                            .font(.title)
                        Text(weather.condition.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Precipitation
                    if let nextHour = weatherManager.hourlyForecast.first {
                        VStack {
                            Text("\(Int(nextHour.precipitation * 100))%")
                                .font(.title2)
                            Text("Rain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                ProgressView()
                    .padding()
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

struct ActivityWidget: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Button("Start") {
                    // Start workout
                }
                .font(.caption)
            }
            
            if workoutManager.isWorkoutActive {
                // Active workout
                VStack(spacing: 8) {
                    Text(formattedDuration)
                        .font(.title)
                    
                    Text(workoutTypeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Spacer()
                        Button("End") {
                            workoutManager.endWorkout()
                        }
                        .foregroundColor(.red)
                    }
                }
            } else {
                // Recent workouts summary
                HStack(spacing: 20) {
                    MetricView(
                        value: "\(Int(workoutManager.activeCalories))",
                        unit: "Cal",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    MetricView(
                        value: formattedDistance,
                        unit: "km",
                        icon: "figure.walk",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    private var formattedDuration: String {
        let time = Int(workoutManager.workoutDuration)
        let minutes = (time % 3600) / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var workoutTypeName: String {
        guard let type = workoutManager.selectedWorkout else { return "No Workout" }
        switch type {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        default:
            return "Workout"
        }
    }
    
    private var formattedDistance: String {
        let distance = workoutManager.distance / 1000 // Convert to kilometers
        return String(format: "%.1f", distance)
    }
}

struct ReminderWidget: View {
    @EnvironmentObject var reminderManager: ReminderManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    // Add reminder
                }
                .font(.caption)
            }
            
            if reminderManager.reminders.isEmpty {
                Text("No upcoming reminders")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(reminderManager.reminders.prefix(3), id: \.calendarItemIdentifier) { reminder in
                    ReminderRow(reminder: reminder)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct MetricView: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .bold()
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            Text(reminder.title)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            if let date = reminder.dueDateComponents?.date {
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
