import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StatusTabView()
                .tabItem {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Status")
                }
                .tag(0)

            DeviceTabView()
                .tabItem {
                    Image(systemName: "iphone")
                    Text("Device")
                }
                .tag(1)

            AppsTabView()
                .tabItem {
                    Image(systemName: "app.badge")
                    Text("Apps")
                }
                .tag(2)

            NetworkTabView()
                .tabItem {
                    Image(systemName: "network")
                    Text("Network")
                }
                .tag(3)

            GPSTabView()
                .tabItem {
                    Image(systemName: "location.fill")
                    Text("GPS")
                }
                .tag(4)

            CellularTabView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Cellular")
                }
                .tag(5)

            HardwareTabView()
                .tabItem {
                    Image(systemName: "cpu")
                    Text("Hardware")
                }
                .tag(6)
        }
        .accentColor(.scAccent)
    }
}
