// HouseMate/Views/Onboarding/AuthView.swift
import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let authService = AuthService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                    if isSignUp {
                        TextField("Your display name", text: $displayName)
                    }
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button(isSignUp ? "Create Account" : "Sign In") {
                        Task { await submit() }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))
                }
                Section {
                    Button(isSignUp ? "Already have an account? Sign In" : "New here? Create Account") {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .disabled(isLoading)
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isSignUp {
                _ = try await authService.signUp(email: email, password: password)
            } else {
                _ = try await authService.signIn(email: email, password: password)
            }
            await appState.loadSession()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
