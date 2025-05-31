import Foundation
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentLocale: Locale
    @Published private(set) var currentLanguage: String
    @Published private(set) var translations: [String: String] = [:]
    @Published private(set) var dateFormatter: DateFormatter
    @Published private(set) var numberFormatter: NumberFormatter
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Supported Languages
    
    let supportedLanguages: [Language] = [
        Language(code: "en", name: "English", region: "US"),
        Language(code: "es", name: "Español", region: "ES"),
        Language(code: "fr", name: "Français", region: "FR"),
        Language(code: "de", name: "Deutsch", region: "DE"),
        Language(code: "it", name: "Italiano", region: "IT"),
        Language(code: "ja", name: "日本語", region: "JP"),
        Language(code: "zh", name: "中文", region: "CN"),
        Language(code: "ko", name: "한국어", region: "KR"),
        Language(code: "ru", name: "Русский", region: "RU"),
        Language(code: "pt", name: "Português", region: "BR")
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Load saved language or use system default
        let savedLanguage = userDefaults.string(forKey: "selectedLanguage") ?? Locale.current.languageCode ?? "en"
        currentLanguage = savedLanguage
        
        // Initialize locale
        currentLocale = Locale(identifier: savedLanguage)
        
        // Initialize formatters
        dateFormatter = DateFormatter()
        dateFormatter.locale = currentLocale
        
        numberFormatter = NumberFormatter()
        numberFormatter.locale = currentLocale
        
        // Load translations
        loadTranslations()
        
        // Setup observers
        setupObservers()
    }
    
    // MARK: - Language Management
    
    func setLanguage(_ languageCode: String) {
        guard languageCode != currentLanguage,
              supportedLanguages.contains(where: { $0.code == languageCode }) else {
            return
        }
        
        currentLanguage = languageCode
        currentLocale = Locale(identifier: languageCode)
        
        // Update formatters
        updateFormatters()
        
        // Load new translations
        loadTranslations()
        
        // Save selection
        userDefaults.set(languageCode, forKey: "selectedLanguage")
        
        // Post notification
        notificationCenter.post(name: .languageDidChange, object: nil)
    }
    
    func translate(_ key: String, _ args: CVarArg...) -> String {
        let format = translations[key] ?? key
        return String(format: format, locale: currentLocale, arguments: args)
    }
    
    // MARK: - Formatting
    
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        dateFormatter.dateStyle = style
        return dateFormatter.string(from: date)
    }
    
    func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        dateFormatter.timeStyle = style
        return dateFormatter.string(from: date)
    }
    
    func formatNumber(_ number: Double, decimals: Int = 2) -> String {
        numberFormatter.maximumFractionDigits = decimals
        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currentLocale
        if let currencyCode = currencyCode {
            formatter.currencyCode = currencyCode
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    func formatMeasurement(_ value: Double, unit: UnitType) -> String {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = currentLocale
        
        switch unit {
        case .distance:
            let measurement = Measurement(value: value, unit: UnitLength.meters)
            return measurementFormatter.string(from: measurement)
        case .weight:
            let measurement = Measurement(value: value, unit: UnitMass.kilograms)
            return measurementFormatter.string(from: measurement)
        case .temperature:
            let measurement = Measurement(value: value, unit: UnitTemperature.celsius)
            return measurementFormatter.string(from: measurement)
        }
    }
    
    // MARK: - Helpers
    
    private func loadTranslations() {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return
        }
        
        // Load strings file
        if let stringsPath = bundle.path(forResource: "Localizable", ofType: "strings"),
           let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String] {
            translations = dict
        }
    }
    
    private func updateFormatters() {
        dateFormatter.locale = currentLocale
        numberFormatter.locale = currentLocale
    }
    
    private func setupObservers() {
        // Watch for system locale changes
        notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleLocaleChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleLocaleChange() {
        // Update formatters to reflect system changes
        updateFormatters()
        
        // Notify observers
        notificationCenter.post(name: .localeDidChange, object: nil)
    }
}

// MARK: - Supporting Types

struct Language: Identifiable {
    let code: String
    let name: String
    let region: String
    
    var id: String { code }
    var identifier: String { "\(code)_\(region)" }
}

enum UnitType {
    case distance
    case weight
    case temperature
}

// MARK: - Text Definitions

extension LocalizationManager {
    enum TextKey {
        // General
        static let ok = "general.ok"
        static let cancel = "general.cancel"
        static let save = "general.save"
        static let edit = "general.edit"
        static let delete = "general.delete"
        static let done = "general.done"
        
        // Health
        static let steps = "health.steps"
        static let heartRate = "health.heartRate"
        static let calories = "health.calories"
        static let distance = "health.distance"
        static let workout = "health.workout"
        
        // Weather
        static let temperature = "weather.temperature"
        static let humidity = "weather.humidity"
        static let wind = "weather.wind"
        static let precipitation = "weather.precipitation"
        
        // Home
        static let devices = "home.devices"
        static let scenes = "home.scenes"
        static let automation = "home.automation"
        
        // Settings
        static let language = "settings.language"
        static let notifications = "settings.notifications"
        static let privacy = "settings.privacy"
        static let about = "settings.about"
        
        // Errors
        static let errorTitle = "error.title"
        static let errorMessage = "error.message"
        static let tryAgain = "error.tryAgain"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
    static let localeDidChange = Notification.Name("localeDidChange")
}

// MARK: - View Extensions

extension View {
    func localizedText(_ key: String, _ args: CVarArg...) -> some View {
        let manager = LocalizationManager.shared
        return text(manager.translate(key, args))
    }
    
    private func text(_ string: String) -> Text {
        Text(string)
    }
}

// MARK: - String Extensions

extension String {
    var localized: String {
        LocalizationManager.shared.translate(self)
    }
    
    func localized(_ args: CVarArg...) -> String {
        LocalizationManager.shared.translate(self, args)
    }
}

// MARK: - Date Extensions

extension Date {
    var formatted: String {
        LocalizationManager.shared.formatDate(self)
    }
    
    var timeFormatted: String {
        LocalizationManager.shared.formatTime(self)
    }
}

// MARK: - Number Extensions

extension Double {
    var formatted: String {
        LocalizationManager.shared.formatNumber(self)
    }
    
    var currencyFormatted: String {
        LocalizationManager.shared.formatCurrency(self)
    }
}
