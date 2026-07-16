import SwiftUI

@main
struct JapaneseTutorApp: App {
    @StateObject private var controller = ConversationController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
        } label: {
            Image(systemName: controller.state.symbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
