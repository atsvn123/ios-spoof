import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DeviceTabView()
                .tabItem {
                    Image(systemName: "iphone")
                    Text("Device")
                }
                .tag(0)

            AppsTabView()
                .tabItem {
                    Image(systemName: "app.badge")
                    Text("Apps")
                }
                .tag(1)

            NetworkTabView()
                .tabItem {
                    Image(systemName: "network")
                    Text("Network")
                }
                .tag(2)

            GPSTabView()
                .tabItem {
                    Image(systemName: "location.fill")
                    Text("GPS")
                }
                .tag(3)

            CellularTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Cellular")
                }
                .tag(4)

            HardwareTabView()
                .tabItem {
                    Image(systemName: "cpu")
                    Text("Hardware")
                }
                .tag(5)
        }
        .tint(.cyan)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
