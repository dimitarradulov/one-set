struct AppDependencies {
  let catalog: ProgramCatalog

  static let live = AppDependencies(catalog: .bundled)
}
