import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AirtableSwiftableTests.allTests),
    ]
}
#endif
