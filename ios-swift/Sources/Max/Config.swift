import Foundation

// Public application configuration, set by the release build's Info.plist.
// Provider secrets belong only in backend/.env or the backend hosting settings.
let kMaxAPIBaseURL = Bundle.main.object(forInfoDictionaryKey: "MAX_API_BASE_URL") as? String ?? ""
let kSupabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "https://placeholder.supabase.co"
let kSupabaseAnonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
