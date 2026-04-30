import SwiftUI

@main
struct ResearchSupportApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appSettings)
        }
    }
}
