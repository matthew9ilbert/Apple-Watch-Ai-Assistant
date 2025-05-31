import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) var dismiss
    
    // Metrics display options
    @State private var selectedMetric: MetricType = .heartRate
    @State private var showingAllMetrics = false
    
    enum MetricType: String, CaseIterable {
        case heartRate = "Heart Rate"
        case pace = "Pace"
        case elevation = "Elevation"
        case cadence = "Cadence"
        case splits = "Splits"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with basic workout info
                workoutHeader
                
                // Main metrics display
                currentMetricsGrid
                
                // Chart section
                metricChart
                
                // Additional metrics and controls
                if showingAllMetrics {
                    allMetricsView
                }
                
                // Action buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var workoutHeader: some View {
        VStack(spacing: 8) {
            // Workout type and status
            HStack {
                Image(systemName: workoutTypeIcon)
                    .font(.title2)
                
                Text(workoutTypeName)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(state: workoutManager.workoutState)
            }
            
            // Duration and distance
            HStack {
                VStack(alignment: .leading) {
                    Text(formattedDuration)
                        .font(.title)
                        .bold()
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(formattedDistance)
                        .font(.title)
                        .bold()
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Current Metrics Grid
    
    private var currentMetricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Heart Rate",
                value: "\(Int(workoutManager.heartRate))",
                unit: "BPM",
                icon: "heart.fill",
                color: .red
            )
            
            MetricCard(
                title: "Calories",
                value: "\(Int(workoutManager.activeCalories))",
                unit: "cal",
                icon: "flame.fill",
                color: .orange
            )
            
            MetricCard(
                title: "Pace",
                value: formattedPace,
                unit: "min/km",
                icon: "speedometer",
                color: .green
            )
            
            MetricCard(
                title: "Elevation",
                value: "\(Int(workoutManager.workoutMetrics.elevationGain))",
                unit: "m",
                icon: "mountain.2.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - Metric Chart
    
    private var metricChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedMetric.rawValue)
                .font(.headline)
            
            Picker("Metric", selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Chart {
                switch selectedMetric {
                case .heartRate:
                    heartRateChartContent
                case .pace:
                    paceChartContent
                case .elevation:
                    elevationChartContent
                case .cadence:
                    cadenceChartContent
                case .splits:
                    splitsChartContent
                }
            }
            .frame(height: 200)
            .padding(.vertical)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - All Metrics View
    
    private var allMetricsView: some View {
        VStack(spacing: 16) {
            Text("Detailed Metrics")
                .font(.headline)
            
            // Splits table
            if !workoutManager.workoutMetrics.splits.isEmpty {
                splitsTable
            }
            
            // Additional metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                MetricRow(title: "Avg Heart Rate", value: "\(Int(workoutManager.averageHeartRate)) BPM")
                MetricRow(title: "Max Heart Rate", value: "\(Int(workoutManager.heartRate)) BPM")
                MetricRow(title: "Steps", value: "\(workoutManager.workoutMetrics.steps)")
                MetricRow(title: "Avg Cadence", value: "\(Int(workoutManager.workoutMetrics.cadence)) spm")
                MetricRow(title: "Power", value: "\(Int(workoutManager.workoutMetrics.power)) W")
                if workoutManager.workoutMetrics.strokeCount > 0 {
                    MetricRow(title: "Strokes", value: "\(workoutManager.workoutMetrics.strokeCount)")
                }
                if workoutManager.workoutMetrics.laps > 0 {
                    MetricRow(title: "Laps", value: "\(workoutManager.workoutMetrics.laps)")
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                showingAllMetrics.toggle()
            }) {
                Label(showingAllMetrics ? "Hide Details" : "Show Details",
                      systemImage: showingAllMetrics ? "chevron.up" : "chevron.down")
            }
            
            Button(action: {
                // Share workout data
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Supporting Views
    
    struct StatusBadge: View {
        let state: WorkoutManager.WorkoutState
        
        var body: some View {
            Text(state.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        
        private var backgroundColor: Color {
            switch state {
            case .running:
                return .green
            case .paused:
                return .orange
            case .stopped:
                return .red
            case .preparing:
                return .blue
            }
        }
    }
    
    struct MetricCard: View {
        let title: String
        let value: String
        let unit: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text(value)
                        .font(.title2)
                        .bold()
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemGray5))
            .cornerRadius(12)
        }
    }
    
    struct MetricRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .bold()
            }
        }
    }
    
    // MARK: - Chart Content
    
    @ViewBuilder
    private var heartRateChartContent: some View {
        // Example heart rate data - replace with actual data
        ForEach(0..<60) { minute in
            LineMark(
                x: .value("Time", minute),
                y: .value("Heart Rate", Double.random(in: 120...160))
            )
            .foregroundStyle(.red)
        }
    }
    
    @ViewBuilder
    private var paceChartContent: some View {
        // Example pace data - replace with actual data
        ForEach(0..<60) { minute in
            LineMark(
                x: .value("Time", minute),
                y: .value("Pace", Double.random(in: 4...6))
            )
            .foregroundStyle(.green)
        }
    }
    
    @ViewBuilder
    private var elevationChartContent: some View {
        // Example elevation data - replace with actual data
        ForEach(0..<60) { minute in
            LineMark(
                x: .value("Time", minute),
                y: .value("Elevation", Double.random(in: 0...100))
            )
            .foregroundStyle(.purple)
        }
    }
    
    @ViewBuilder
    private var cadenceChartContent: some View {
        // Example cadence data - replace with actual data
        ForEach(0..<60) { minute in
            LineMark(
                x: .value("Time", minute),
                y: .value("Cadence", Double.random(in: 150...180))
            )
            .foregroundStyle(.blue)
        }
    }
    
    @ViewBuilder
    private var splitsChartContent: some View {
        // Example splits data - replace with actual data
        ForEach(workoutManager.workoutMetrics.splits.indices, id: \.self) { index in
            BarMark(
                x: .value("Split", index + 1),
                y: .value("Pace", workoutManager.workoutMetrics.splits[index].pace)
            )
            .foregroundStyle(.orange)
        }
    }
    
    // MARK: - Supporting Views and Functions
    
    private var workoutTypeIcon: String {
        switch workoutManager.selectedWorkout {
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        default:
            return "figure.walk"
        }
    }
    
    private var workoutTypeName: String {
        switch workoutManager.selectedWorkout {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        default:
            return "Workout"
        }
    }
    
    private var formattedDuration: String {
        let interval = Int(workoutManager.workoutDuration)
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var formattedDistance: String {
        let distance = workoutManager.distance
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    private var formattedPace: String {
        let pace = workoutManager.pace
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var splitsTable: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Split")
                    .frame(width: 60, alignment: .leading)
                Text("Distance")
                    .frame(width: 80, alignment: .leading)
                Text("Pace")
                    .frame(width: 80, alignment: .leading)
                Text("HR")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            ForEach(workoutManager.workoutMetrics.splits.indices, id: \.self) { index in
                let split = workoutManager.workoutMetrics.splits[index]
                HStack {
                    Text("\(index + 1)")
                        .frame(width: 60, alignment: .leading)
                    Text(String(format: "%.2f km", split.distance / 1000))
                        .frame(width: 80, alignment: .leading)
                    Text(formatPace(split.pace))
                        .frame(width: 80, alignment: .leading)
                    Text("\(Int(split.averageHeartRate))")
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
