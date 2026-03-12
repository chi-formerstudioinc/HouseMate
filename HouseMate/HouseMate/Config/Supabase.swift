// HouseMate/Config/Supabase.swift
import Foundation
import Supabase

let supabase: SupabaseClient = {
    guard let url = URL(string: Secrets.supabaseURL),
          !Secrets.supabaseURL.contains("YOUR_PROJECT") else {
        preconditionFailure("Configure Secrets.swift: set supabaseURL to your Supabase project URL")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
}()
