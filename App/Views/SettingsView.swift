import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Avvio") {
                Toggle("Apri Mosaic all'accesso", isOn: Binding(
                    get: { model.loginItemStatus == .enabled || model.loginItemStatus == .requiresApproval },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if model.loginItemStatus == .requiresApproval {
                    Text("macOS chiede di approvare l'avvio in Impostazioni di Sistema → Generali → Elementi login.")
                        .foregroundStyle(.secondary)
                    Button("Apri Elementi login") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
                if let error = model.loginItemError {
                    Text(error)
                        .foregroundStyle(.red)
                }
                Text("Chiudere la finestra lascia Mosaic nella barra dei menu. Uscire da Mosaic ferma ogni attività in background.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .task { await model.refresh() }
    }
}
