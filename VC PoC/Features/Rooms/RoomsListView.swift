import SwiftUI

struct RoomsListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isPresentingCreateJoin = false

    var body: some View {
        NavigationStack {
            List(viewModel.rooms) { room in
                NavigationLink(value: room) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .font(.headline)
                        Text("Code: \(room.inviteCode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if viewModel.rooms.isEmpty {
                    ContentUnavailableView(
                        "No rooms yet",
                        systemImage: "person.3.sequence.fill",
                        description: Text("Tap + to create or join a room.")
                    )
                }
            }
            .navigationTitle("Your Rooms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") {
                        Task { await viewModel.signOut() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateJoin = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: VoiceRoom.self) { room in
                RoomVoiceView(viewModel: viewModel, room: room)
            }
            .sheet(isPresented: $isPresentingCreateJoin) {
                CreateOrJoinRoomView(viewModel: viewModel)
            }
            .task {
                try? await viewModel.reloadRooms()
            }
            .refreshable {
                try? await viewModel.reloadRooms()
            }
        }
    }
}
