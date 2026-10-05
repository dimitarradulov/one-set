struct CompletedOnboarding: Codable, Sendable {
  let setup: AccountSetup
  var needsUpload: Bool
}
