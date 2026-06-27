import SwiftUI

struct AppsTabView: View {
    @StateObject private var viewModel = AppsViewModel.shared
    @State private var searchText = ""
    @State private var showSystemApps = false

    var filteredApps: [AppInfo] {
        let apps = showSystemApps ? viewModel.apps : viewModel.apps.filter { !$0.isSystemApp }
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    Section {
                        HStack {
                            Text("Đã chọn")
                            Spacer()
                            Text("\(viewModel.selectedApps.count) app")
                                .foregroundColor(.scAccent)
                                .fontWeight(.medium)
                        }

                        Button {
                            viewModel.select(filteredApps)
                        } label: {
                            Label("Chọn tất cả đang hiển thị", systemImage: "checkmark.circle.fill")
                        }

                        Button {
                            viewModel.deselectAll()
                        } label: {
                            Label("Bỏ chọn tất cả", systemImage: "xmark.circle")
                        }
                        .foregroundColor(.red)
                    }

                    Section {
                        TextField("Tìm kiếm app...", text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Toggle("Hiển thị app hệ thống", isOn: $showSystemApps)
                    }

                    Section(header: Text("Ứng dụng đã cài (\(filteredApps.count))")) {
                        ForEach(filteredApps) { app in
                            AppRowView(app: app, isSelected: viewModel.isSelected(app)) {
                                viewModel.toggle(app)
                            }
                        }
                    }
                }

                if viewModel.isLoading && viewModel.apps.isEmpty {
                    ProgressView("Đang tải ứng dụng...")
                } else if viewModel.apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Không tìm thấy ứng dụng nào")
                            .foregroundColor(.secondary)
                        Text("Đảm bảo app chạy trên thiết bị đã jailbreak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ứng dụng")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.loadApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.scAccent)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
