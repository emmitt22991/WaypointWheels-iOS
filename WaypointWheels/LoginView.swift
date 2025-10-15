import SwiftUI

@MainActor
struct LoginView: View {
    @ObservedObject var viewModel: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome back")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("you@example.com", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
            }

            Button(action: viewModel.signIn) {
                Text(viewModel.isLoading ? "Signing In…" : "Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            if viewModel.canUseBiometricLogin {
                Button(action: viewModel.authenticateWithBiometrics) {
                    Label(viewModel.biometricButtonTitle, systemImage: viewModel.biometricButtonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: SessionViewModel())
        .padding()
}
