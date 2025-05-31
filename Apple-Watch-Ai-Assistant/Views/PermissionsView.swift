import SwiftUI
import HealthKit
import CoreLocation

struct PermissionsView: View {
    @EnvironmentObject var permissionsManager: PermissionsManager
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    
    @State private var showingDetail: PermissionsManager.PermissionType?
    @State private var processingPermission: PermissionsManager.PermissionType?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    permissionsGrid
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if permissionsManager.allPermissionsGranted {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
            }
            .alert("Permission Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("App Permissions")
                .font(.title2)
                .bold()
            
            Text("WatchAssistant needs access to certain features to provide you with the best experience. Please review and grant the following permissions:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Permissions Grid
    
    private var permissionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(PermissionsManager.PermissionType.allCases, id: \.rawValue) { permission in
                PermissionCard(
                    permission: permission,
                    isAuthorized: isPermissionAuthorized(permission),
                    isProcessing: processingPermission == permission
                ) {
                    await requestPermission(permission)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await requestAllPermissions()
                }
            }) {
                Text(permissionsManager.allPermissionsGranted ? "All Permissions Granted" : "Grant All Permissions")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(permissionsManager.allPermissionsGranted ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(permissionsManager.allPermissionsGranted)
            
            if !permissionsManager.allPermissionsGranted {
                Button("Skip for Now") {
                    isPresented = false
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isPermissionAuthorized(_ permission: PermissionsManager.PermissionType) -> Bool {
        switch permission {
        case .healthKit:
            return permissionsManager.healthKitAuthorized
        case .location:
            return permissionsManager.locationAuthorized
        case .notifications:
            return permissionsManager.notificationsAuthorized
        case .microphone:
            return permissionsManager.microphoneAuthorized
        case .speechRecognition:
            return permissionsManager.speechRecognitionAuthorized
        case .contacts:
            return permissionsManager.contactsAuthorized
        case .homeKit:
            return permissionsManager.homeKitAuthorized
        }
    }
    
    private func requestPermission(_ permission: PermissionsManager.PermissionType) async {
        processingPermission = permission
        
        do {
            switch permission {
            case .healthKit:
                try await permissionsManager.requestHealthKitAuthorization()
            case .location:
                permissionsManager.requestLocationAuthorization()
            case .notifications:
                try await permissionsManager.requestNotificationAuthorization()
            case .microphone:
                try await permissionsManager.requestMicrophoneAuthorization()
            case .speechRecognition:
                try await permissionsManager.requestSpeechRecognitionAuthorization()
            case .contacts:
                try await permissionsManager.requestContactsAuthorization()
            case .homeKit:
                try await permissionsManager.requestHomeKitAuthorization()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        processingPermission = nil
    }
    
    private func requestAllPermissions() async {
        await permissionsManager.requestAllPermissions()
    }
}

// MARK: - Permission Card View

struct PermissionCard: View {
    let permission: PermissionsManager.PermissionType
    let isAuthorized: Bool
    let isProcessing: Bool
    let action: () async -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: permissionIcon)
                .font(.system(size: 30))
                .foregroundColor(isAuthorized ? .green : .blue)
            
            // Title
            Text(permission.rawValue)
                .font(.headline)
            
            // Status
            if isProcessing {
                ProgressView()
            } else {
                Image(systemName: isAuthorized ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isAuthorized ? .green : .gray)
            }
            
            // Description
            Text(permission.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action Button
            if !isAuthorized && !isProcessing {
                Button(action: {
                    Task {
                        await action()
                    }
                }) {
                    Text("Grant Access")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    private var permissionIcon: String {
        switch permission {
        case .healthKit:
            return "heart.fill"
        case .location:
            return "location.fill"
        case .notifications:
            return "bell.fill"
        case .microphone:
            return "mic.fill"
        case .speechRecognition:
            return "waveform"
        case .contacts:
            return "person.crop.circle.fill"
        case .homeKit:
            return "house.fill"
        }
    }
}

// MARK: - Extensions

extension PermissionsManager.PermissionType: CaseIterable {
    static var allCases: [PermissionsManager.PermissionType] = [
        .healthKit,
        .location,
        .notifications,
        .microphone,
        .speechRecognition,
        .contacts,
        .homeKit
    ]
}

// MARK: - Preview Provider

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView(isPresented: .constant(true))
            .environmentObject(PermissionsManager.shared)
    }
}
