// HouseMate/Services/AuthService.swift
import Supabase
import Foundation

@MainActor
final class AuthService {
    var currentUser: User? { supabase.auth.currentUser }

    func signUp(email: String, password: String) async throws -> User {
        let response = try await supabase.auth.signUp(email: email, password: password)
        return response.user
    }

    func signIn(email: String, password: String) async throws -> User {
        let session = try await supabase.auth.signIn(email: email, password: password)
        return session.user
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func restoreSession() async throws -> User? {
        _ = try await supabase.auth.session
        return supabase.auth.currentUser
    }
}
