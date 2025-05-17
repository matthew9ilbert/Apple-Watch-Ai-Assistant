import SwiftUI
import HealthKit

struct FitnessView: View {
    @EnvironmentObject var healthManager: HealthManager
    
    @State private var selectedWorkout: HKWorkoutActivityType?
    @State private var isWorkoutActive = false
    @State private var workoutDuration: TimeInterval = 0
    @State private var workoutStartTime: Date?
    @State private var timer: Timer?
    
    private let workoutTypes: [(String, HKWorkoutActivityType)] = [
        ("Walking", .walking),
        ("Running", .running),
        ("Cycling", .cycling),
        ("Hiking", .hiking),
        ("Swimming", .swimming),
        ("Yoga", .yoga),
        ("HIIT", .highIntensityIntervalTraining),
        ("Strength", .traditionalStrengthTraining)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isWorkoutActive {
                    // Active workout display
                    activeWorkoutView
                } else {
                    // Workout selection
                    workoutSelectionView
                }
                
                // Health metrics
                healthMetricsView
                
                // Health tips
                healthTipsView
            }
            .padding()
        }
    }
    
    // View for selecting a workout
    private var workoutSelectionView: some View {
        VStack(spacing: 12) {
            Text("Select Workout")
                .font(.headline)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(workoutTypes, id: \.0) { type in
                    Button(action: {
                        selectedWorkout = type.1
                        startWorkout()
                    }) {
                        VStack {
                            Image(systemName: workoutIcon(for: type.1))
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text(type.0)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    // View for active workout
    private var activeWorkoutView: some View {
        VStack(spacing: 16) {
            if let workout = selectedWorkout {
                // Workout type and icon
                HStack {
                    Image(systemName: workoutIcon(for: workout))
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text(workoutName(for: workout))
                        .font(.headline)
                }
                
                // Timer
                Text(formattedDuration)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                
                // Controls
                HStack(spacing: 30) {
                    Button(action: {
                        pauseWorkout()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        endWorkout()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    // View for health metrics
    private var healthMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 20) {
                // Heart rate
                VStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(healthManager.currentHeartRate ?? 0) BPM")
                        .font(.system(.body, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                
                // Steps
                VStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.green)
                    Text("\(healthManager.stepCount)")
                        .font(.system(.body, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                
                // Calories
                VStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(Int(healthManager.activeCalories)) cal")
                        .font(.system(.body, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    // View for health tips
    private var healthTipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health Tip")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(healthManager.healthTips, id: \.self) { tip in
                Text(tip)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    
    private func workoutIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .yoga:
            return "figure.mind.and.body"
        case .hiking:
            return "mountain.2"
        case .highIntensityIntervalTraining:
            return "timer"
        case .traditionalStrengthTraining:
            return "dumbbell"
        default:
            return "heart.circle"
        }
    }
    
    private func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .hiking:
            return "Hiking"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .traditionalStrengthTraining:
            return "Strength"
        default:
            return "Workout"
        }
    }
    
    private var formattedDuration: String {
        let hours = Int(workoutDuration) / 3600
        let minutes = (Int(workoutDuration) % 3600) / 60
        let seconds = Int(workoutDuration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Workout Control
    
    private func startWorkout() {
        guard !isWorkoutActive, let workout = selectedWorkout else { return }
        
        isWorkoutActive = true
        workoutStartTime = Date()
        
        // Start workout in health manager
        healthManager.startWorkout(workoutType: workout)
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = workoutStartTime {
                workoutDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func pauseWorkout() {
        // In a real app, this would pause the workout session
        // For this demo, we just toggle the timer
        
        if timer?.isValid ?? false {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let startTime = workoutStartTime {
                    workoutDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    private func endWorkout() {
        // End workout session
        timer?.invalidate()
        timer = nil
        
        // In a real app, this would end the workout in HealthKit
        
        // Reset state
        isWorkoutActive = false
        workoutDuration = 0
        workoutStartTime = nil
        selectedWorkout = nil
    }
}
