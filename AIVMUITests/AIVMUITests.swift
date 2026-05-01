import XCTest

final class AIVMUITests: XCTestCase {
  func testRootShellLaunches() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.staticTexts["home.empty.title"].waitForExistence(timeout: 5))
  }
}
