import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Assistant tab
            AssistantView()
                .tag(0)
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Assistant")
                }
            
            // Fitness tab
            FitnessView()
                .tag(1)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Fitness")
                }
            
            // Home control tab
            HomeControlView()
                .tag(2)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // Settings tab
            SettingsView()
                .tag(3)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}
