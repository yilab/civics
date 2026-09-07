import Foundation

/// Resolves String Catalog keys against the bundle for the in-app language
/// selection. The bundle is swapped before the view tree rebuilds (RootView is
/// keyed on `uiLanguage`), so `t(_:)` is safe to call directly in view bodies.
@MainActor
enum L10n {

    static var bundle: Bundle = .main

    static func t(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Formats a localized pattern with `String(format:)`.
    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    /// Points the resolver at the chosen language; call before re-rendering.
    static func apply(_ language: UiLanguage) {
        switch language {
        case .system:
            bundle = .main
        case .english:
            bundle = lproj("en") ?? .main
        case .chinese:
            bundle = lproj("zh-Hans") ?? .main
        }
    }

    private static func lproj(_ name: String) -> Bundle? {
        Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}

/// Display names for the canonical (English) category strings —
/// the stored setting value never changes, only its presentation.
@MainActor
enum CategoriesL10n {
    static func name(_ raw: String) -> String {
        switch raw {
        case Categories.all: L10n.t("category.all")
        case "American Government": L10n.t("category.americanGovernment")
        case "American History": L10n.t("category.americanHistory")
        case "Symbols & Holidays": L10n.t("category.symbolsHolidays")
        default: raw
        }
    }
}
