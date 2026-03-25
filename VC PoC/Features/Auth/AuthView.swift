import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .signIn

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(mode.rawValue) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)

                    Button {
                        Task {
                            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            if mode == .signIn {
                                await viewModel.signIn(email: trimmedEmail, password: password)
                            } else {
                                await viewModel.signUp(email: trimmedEmail, password: password)
                            }
                        }
                    } label: {
                        if viewModel.isBusy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode.rawValue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(
                        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        password.count < 6 ||
                        viewModel.isBusy
                    )
                }
            }
            .navigationTitle("Voice Rooms")
        }
    }
}
