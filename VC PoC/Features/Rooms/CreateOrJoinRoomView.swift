import SwiftUI

struct CreateOrJoinRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel

    @State private var roomName = ""
    @State private var roomCode = ""
    @State private var isSubmittingCreate = false
    @State private var isSubmittingJoin = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Create room") {
                    TextField("Room name", text: $roomName)
                    Button("Create") {
                        Task {
                            isSubmittingCreate = true
                            defer { isSubmittingCreate = false }
                            let didCreate = await viewModel.createRoom(name: roomName.trimmingCharacters(in: .whitespacesAndNewlines))
                            if didCreate {
                                dismiss()
                            }
                        }
                    }
                    .disabled(roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingCreate)
                }

                Section("Join room") {
                    TextField("4-digit code", text: $roomCode)
                        .keyboardType(.numberPad)
                    Button("Join") {
                        Task {
                            isSubmittingJoin = true
                            defer { isSubmittingJoin = false }
                            let didJoin = await viewModel.joinRoom(code: roomCode)
                            if didJoin {
                                dismiss()
                            }
                        }
                    }
                    .disabled(roomCode.filter(\.isNumber).count != 4 || isSubmittingJoin)
                }
            }
            .navigationTitle("Create or Join")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
