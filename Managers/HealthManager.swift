import Foundation
import HealthKit
import Combine

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let heartRateQuantity = HKUnit(from: "count/min")
    
    @Published var currentHeartRate: Int?
    @Published var stepCount: Int = 0
    @Published var activeCalories: Double = 0
    @Published var healthTips: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        generateHealthTips()
    }
    
    func requestAuthorization() {
        // Define the health data types to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        
        // Request authorization from the user
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization request was successful!")
                self.startHeartRateQuery()
                self.fetchTodayStepCount()
                self.fetchActiveCalories()
            } else if let error = error {
                print("HealthKit authorization failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Set up heart rate streaming from watch sensor
        let datePredicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: nil, options: .strictEndDate)
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let queryPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, devicePredicate])
        
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { _, samples, _, _, error in
            if let error = error {
                print("Heart rate query error: \(error.localizedDescription)")
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            DispatchQueue.main.async {
                if let mostRecentSample = samples.last {
                    self.currentHeartRate = Int(mostRecentSample.quantity.doubleValue(for: self.heartRateQuantity))
                    
                    // Generate health insights based on heart rate
                    self.generateHealthInsights()
                }
            }
        }
        
        let heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: queryPredicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: updateHandler
        )
        
        heartRateQuery.updateHandler = updateHandler
        
        healthStore.execute(heartRateQuery)
    }
    
    func fetchTodayStepCount() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                if let error = error {
                    print("Step count query error: \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.stepCount = Int(sum.doubleValue(for: HKUnit.count()))
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchActiveCalories() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: caloriesType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                if let error = error {
                    print("Calories query error: \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.activeCalories = sum.doubleValue(for: HKUnit.kilocalorie())
            }
        }
        
        healthStore.execute(query)
    }
    
    func startWorkout(workoutType: HKWorkoutActivityType) {
        // Implement workout tracking functionality
        // This would start a workout session and begin tracking relevant metrics
    }
    
    private func generateHealthInsights() {
        // Use health data to generate personalized insights
        guard let heartRate = currentHeartRate else { return }
        
        if heartRate > 100 {
            // High heart rate detection
            healthTips = ["Your heart rate is elevated. Consider taking a moment to breathe deeply.",
                         "Elevated heart rate detected. Are you exercising or feeling stressed?"]
        } else if heartRate < 50 {
            // Low heart rate detection (normal for some athletes)
            healthTips = ["Your heart rate is lower than average. This can be normal for athletes.",
                         "Low resting heart rate detected. This often indicates good cardiovascular fitness."]
        } else {
            // Normal range
            healthTips = ["Your heart rate is in a healthy range.",
                         "Your vital signs look good. Keep up the healthy habits!"]
        }
    }
    
    private func generateHealthTips() {
        // General health tips that rotate periodically
        let tips = [
            "Try to get at least 7-8 hours of sleep tonight.",
            "Remember to stay hydrated throughout the day.",
            "Taking short breaks to stand and stretch can improve circulation.",
            "Deep breathing exercises can help reduce stress and improve focus.",
            "Aim for 150 minutes of moderate exercise each week.",
            "Regular meditation can help reduce stress and improve mental clarity.",
            "Tracking your sleep patterns can help improve sleep quality.",
            "Try to maintain a consistent sleep schedule, even on weekends."
        ]
        
        healthTips = [tips.randomElement()!]
        
        // Update tips periodically
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.healthTips = [tips.randomElement()!]
            }
            .store(in: &cancellables)
    }
}
