import Foundation
import HealthKit
import CoreMotion
import Combine

class WorkoutManager: NSObject, ObservableObject {
    // Published properties for UI updates
    @Published var isWorkoutActive = false
    @Published var showingSummaryView = false
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var workoutDuration: TimeInterval = 0
    @Published var activeCalories: Double = 0
    @Published var heartRate: Double = 0
    @Published var distance: Double = 0
    @Published var pace: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var workoutState: WorkoutState = .stopped
    
    // Workout metrics
    @Published var workoutMetrics = WorkoutMetrics()
    
    // Current workout session
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // HealthKit store
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    
    // Timer for updating workout duration
    private var timer: Timer?
    private var startDate: Date?
    
    // Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    enum WorkoutState {
        case preparing
        case running
        case paused
        case stopped
    }
    
    struct WorkoutMetrics {
        var elevationGain: Double = 0
        var steps: Int = 0
        var cadence: Double = 0
        var power: Double = 0
        var strokeCount: Int = 0 // For swimming
        var laps: Int = 0
        var splits: [Split] = []
        
        struct Split {
            let distance: Double
            let duration: TimeInterval
            let pace: Double
            let averageHeartRate: Double
        }
    }
    
    override init() {
        super.init()
        requestAuthorization()
        setupMotionManager()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let typesToRead: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("Authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Workout Control
    
    func startWorkout(_ workoutType: HKWorkoutActivityType) {
        guard let workoutConfiguration = setupWorkoutConfiguration(for: workoutType) else { return }
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            builder = session?.associatedWorkoutBuilder()
            
            // Setup session and builder
            session?.delegate = self
            builder?.delegate = self
            
            // Set up data collection
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: workoutConfiguration
            )
            
            // Start the workout session
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("Error beginning collection: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.startDate = startDate
                    self.workoutState = .running
                    self.isWorkoutActive = true
                    self.selectedWorkout = workoutType
                    self.startTimer()
                }
            }
        } catch {
            print("Error starting workout: \(error.localizedDescription)")
        }
    }
    
    func pauseWorkout() {
        session?.pause()
        workoutState = .paused
        timer?.invalidate()
    }
    
    func resumeWorkout() {
        session?.resume()
        workoutState = .running
        startTimer()
    }
    
    func endWorkout() {
        session?.end()
        showingSummaryView = true
        timer?.invalidate()
    }
    
    // MARK: - Workout Configuration
    
    private func setupWorkoutConfiguration(for workoutType: HKWorkoutActivityType) -> HKWorkoutConfiguration? {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = locationTypeForWorkout(workoutType)
        
        return configuration
    }
    
    private func locationTypeForWorkout(_ workoutType: HKWorkoutActivityType) -> HKWorkoutSessionLocationType {
        switch workoutType {
        case .running, .cycling, .hiking:
            return .outdoor
        case .swimming:
            return .indoor
        default:
            return .indoor
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.workoutDuration = Date().timeIntervalSince(startDate)
        }
    }
    
    // MARK: - Motion Data Collection
    
    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30 Hz
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                self?.processMotionData(motion)
            }
        }
    }
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        // Process motion data for advanced metrics
        let attitude = motion.attitude
        let rotation = motion.rotationRate
        let acceleration = motion.userAcceleration
        
        // Calculate cadence from acceleration patterns
        calculateCadence(from: acceleration)
        
        // Update elevation data if available
        if let altitude = motion.pressure?.altitude {
            updateElevationGain(altitude)
        }
    }
    
    private func calculateCadence(from acceleration: CMAcceleration) {
        // Implement cadence calculation algorithm
        // This would analyze acceleration patterns to detect steps/strokes
    }
    
    private func updateElevationGain(_ currentAltitude: Double) {
        // Track elevation changes over time
    }
    
    // MARK: - Metrics Calculation
    
    private func updateWorkoutMetrics(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        for sample in samples {
            switch sample.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                let value = sample.quantity.doubleValue(for: heartRateUnit)
                DispatchQueue.main.async {
                    self.heartRate = value
                }
                
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                let value = sample.quantity.doubleValue(for: energyUnit)
                DispatchQueue.main.async {
                    self.activeCalories = value
                }
                
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                let distanceUnit = HKUnit.meter()
                let value = sample.quantity.doubleValue(for: distanceUnit)
                DispatchQueue.main.async {
                    self.distance = value
                    self.updatePace()
                }
                
            default:
                break
            }
        }
    }
    
    private func updatePace() {
        guard distance > 0, workoutDuration > 0 else { return }
        pace = workoutDuration / (distance / 1000) // min/km
    }
    
    // MARK: - Workout Summary
    
    func generateWorkoutSummary() -> WorkoutSummary {
        return WorkoutSummary(
            duration: workoutDuration,
            calories: activeCalories,
            distance: distance,
            averageHeartRate: averageHeartRate,
            pace: pace,
            elevationGain: workoutMetrics.elevationGain,
            steps: workoutMetrics.steps,
            splits: workoutMetrics.splits
        )
    }
    
    struct WorkoutSummary {
        let duration: TimeInterval
        let calories: Double
        let distance: Double
        let averageHeartRate: Double
        let pace: Double
        let elevationGain: Double
        let steps: Int
        let splits: [WorkoutMetrics.Split]
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState,
                       date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.workoutState = .running
            case .paused:
                self.workoutState = .paused
            case .ended:
                self.workoutState = .stopped
                self.builder?.endCollection(withEnd: date) { success, error in
                    self.builder?.finishWorkout { workout, error in
                        DispatchQueue.main.async {
                            self.isWorkoutActive = false
                            self.showingSummaryView = true
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didFailWithError error: Error) {
        print("Workout session failed with error: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let samples = workoutBuilder.statistics(for: quantityType)?.sources?.flatMap { $0.samples } ?? []
            updateWorkoutMetrics(samples)
        }
    }
}
