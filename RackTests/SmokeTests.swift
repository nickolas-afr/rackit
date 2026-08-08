import Testing
@testable import Rack

@Suite("Harness")
struct SmokeTests {
    @Test("Test target is wired to the app target")
    func testTargetLinksApp() {
        // Referencing an app type proves @testable import resolves.
        _ = RootView()
    }
}
