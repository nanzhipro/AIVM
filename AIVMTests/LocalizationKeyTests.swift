import XCTest

@testable import AIVM

final class LocalizationKeyTests: XCTestCase {
  func testLocalizationKeysAreUnique() {
    let keys = LocalizationKey.allCases.map(\.rawValue)
    XCTAssertEqual(Set(keys).count, keys.count)
  }

  func testRequiredLocalesResolveEveryKey() throws {
    let appBundle = Bundle(for: AppBundleMarker.self)
    let languages = ["en", "zh-Hans", "ja"]

    for language in languages {
      let localeURL = try XCTUnwrap(
        appBundle.url(forResource: language, withExtension: "lproj"), language)
      let localeBundle = try XCTUnwrap(Bundle(url: localeURL), language)

      for key in LocalizationKey.allCases {
        let value = localeBundle.localizedString(
          forKey: key.rawValue, value: nil, table: "Localizable")
        XCTAssertNotEqual(value, key.rawValue, "Missing \(key.rawValue) in \(language)")
        XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }
}
