import SwiftUI
import StoreKit
import SafariServices

struct IntegrationsView: View {
    @State private var searchText = ""
    @State private var selectedCategory: IntegrationType = .all
    @State private var showingAuthSheet = false
    @State private var selectedApp: AppIntegration?
    @State private var connectedApps: Set<String> = []
    @State private var showingStoreKit = false
    @State private var showingAppDetails = false
    
    enum IntegrationType: String, CaseIterable {
        case all = "All"
        case health = "Health & Fitness"
        case productivity = "Productivity"
        case lifestyle = "Lifestyle"
        case social = "Social"
    }
    
    struct AppIntegration: Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let category: IntegrationType
        let features: [String]
        let appStoreId: String?
        let universalLink: String?
        let authType: AuthType
        
        enum AuthType {
            case oauth
            case apiKey
            case appLink
            case none
        }
    }
    
    // Sample integrations
    private let availableIntegrations: [AppIntegration] = [
        AppIntegration(
            id: "strava",
            name: "Strava",
            description: "Connect your fitness activities",
            icon: "figure.run",
            category: .health,
            features: ["Activity sync", "Route tracking", "Social sharing"],
            appStoreId: "426826309",
            universalLink: "strava://",
            authType: .oauth
        ),
        AppIntegration(
            id: "things",
            name: "Things",
            description: "Task and project management",
            icon: "checklist",
            category: .productivity,
            features: ["Task sync", "Project import", "Due dates"],
            appStoreId: "904237743",
            universalLink: "things:///",
            authType: .appLink
        ),
        // Add more integrations here
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search bar
                searchBar
                
                // Category filter
                categoryPicker
                
                // Integration list
                integrationsList
            }
            .padding()
        }
        .navigationTitle("Integrations")
        .sheet(isPresented: $showingAuthSheet) {
            if let app = selectedApp {
                AuthorizationView(app: app, isAuthorized: connectedApps.contains(app.id))
            }
        }
        .sheet(isPresented: $showingStoreKit) {
            if let app = selectedApp, let appId = app.appStoreId {
                StoreKitView(appId: appId)
            }
        }
        .sheet(isPresented: $showingAppDetails) {
            if let app = selectedApp {
                AppDetailsView(app: app, isConnected: connectedApps.contains(app.id))
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search integrations", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    // MARK: - Category Picker
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(IntegrationType.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Integrations List
    
    private var integrationsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(filteredIntegrations) { app in
                IntegrationCard(
                    app: app,
                    isConnected: connectedApps.contains(app.id)
                ) {
                    selectedApp = app
                    showingAppDetails = true
                }
            }
        }
    }
    
    private var filteredIntegrations: [AppIntegration] {
        availableIntegrations.filter { app in
            let categoryMatch = selectedCategory == .all || app.category == selectedCategory
            let searchMatch = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.description.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && searchMatch
        }
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.callout, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct IntegrationCard: View {
    let app: IntegrationsView.AppIntegration
    let isConnected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // App icon
                Image(systemName: app.icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // App info
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline)
                    
                    Text(app.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection status
                Image(systemName: isConnected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(isConnected ? .green : .blue)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AuthorizationView: View {
    let app: IntegrationsView.AppIntegration
    let isAuthorized: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App header
                VStack(spacing: 12) {
                    Image(systemName: app.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Connect to \(app.name)")
                        .font(.title2)
                        .bold()
                    
                    Text("This will allow WatchAssistant to:")
                        .foregroundColor(.secondary)
                }
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(app.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feature)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                if isAuthorized {
                    Button(role: .destructive) {
                        // Disconnect app
                        dismiss()
                    } label: {
                        Text("Disconnect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        // Connect app
                        dismiss()
                    } label: {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct AppDetailsView: View {
    let app: IntegrationsView.AppIntegration
    let isConnected: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App header
                    VStack(spacing: 12) {
                        Image(systemName: app.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(app.name)
                            .font(.title2)
                            .bold()
                        
                        Text(app.description)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Features section
                    SectionView(title: "Features") {
                        ForEach(app.features, id: \.self) { feature in
                            FeatureRow(title: feature)
                        }
                    }
                    
                    // Integration options
                    SectionView(title: "Integration") {
                        if isConnected {
                            DisconnectButton {
                                // Handle disconnect
                                dismiss()
                            }
                        } else {
                            ConnectButton {
                                // Handle connect
                                dismiss()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct FeatureRow: View {
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(title)
            Spacer()
        }
    }
}

struct ConnectButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "link")
                Text("Connect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

struct DisconnectButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                Image(systemName: "link.badge.minus")
                Text("Disconnect")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(8)
        }
    }
}

// MARK: - StoreKit View

struct StoreKitView: UIViewControllerRepresentable {
    let appId: String
    
    func makeUIViewController(context: Context) -> SKStoreProductViewController {
        let controller = SKStoreProductViewController()
        controller.loadProduct(withParameters: [
            SKStoreProductParameterITunesItemIdentifier: appId
        ])
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SKStoreProductViewController, context: Context) {}
}
