import Testing
import Markdown

struct SmokeTests {
    @Test func parserIsAvailable() {
        let document = Document(parsing: "# Title")
        #expect(document.childCount == 1)
    }
}
