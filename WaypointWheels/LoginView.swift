import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            Button(action: viewModel.signIn) {
                Text(viewModel.isLoading ? "Signing In…" : "Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let requestJSON = viewModel.requestJSON, !requestJSON.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Request")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(requestJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }

            if let responseJSON = viewModel.responseJSON, !responseJSON.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Response")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(responseJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

#Preview {
    LoginView(viewModel: SessionViewModel())
        .padding()
}
