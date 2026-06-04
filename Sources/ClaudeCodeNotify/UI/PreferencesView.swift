import SwiftUI

/// Store observável das preferências — salva no disco a cada mudança.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published var prefs: Preferences {
        didSet { prefs.save() }
    }
    init() { prefs = Preferences.load() }
}

/// Janela de Preferências: duração + som por tipo de notificação.
struct PreferencesView: View {
    @StateObject private var store = PreferencesStore()

    var body: some View {
        Form {
            Section("Claude needs permission") {
                typeRow($store.prefs.permission)
            }
            Section("Claude is idle (waiting for input)") {
                typeRow($store.prefs.idle)
            }
            Section("Claude finished the task") {
                typeRow($store.prefs.stop)
            }
            Section {
                Text("Duration 0 = the notification stays until you dismiss it (Esc/click).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 540)
    }

    @ViewBuilder
    private func typeRow(_ pref: Binding<Preferences.TypePref>) -> some View {
        // Duração
        HStack {
            Text("Time on screen")
            Spacer()
            Text(pref.wrappedValue.durationSeconds == 0
                 ? "until dismissed"
                 : "\(Int(pref.wrappedValue.durationSeconds))s")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: pref.durationSeconds, in: 0...120, step: 1)
                .labelsHidden()
        }
        // Som
        HStack {
            Picker("Sound", selection: Binding(
                get: { pref.wrappedValue.soundName ?? "" },
                set: { pref.wrappedValue.soundName = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(Preferences.availableSounds, id: \.self) { name in
                    Text(name.isEmpty ? "None" : name).tag(name)
                }
            }
            Button {
                NotificationSound.play(pref.wrappedValue.soundName)
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .disabled((pref.wrappedValue.soundName ?? "").isEmpty)
            .help("Preview")
        }
    }
}
