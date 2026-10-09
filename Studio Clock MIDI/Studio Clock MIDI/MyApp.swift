import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Settings {
            SettingsView().frame(minWidth: 600, minHeight: 150)
        }
    }
}
