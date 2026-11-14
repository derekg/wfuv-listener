import SwiftUI

@main
struct FUVListenerApp: App {
    @StateObject private var radio = RadioStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(radio)
        }
    }
}
