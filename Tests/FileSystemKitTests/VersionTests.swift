// FileSystemKit Tests
// Version Types Unit Tests
//
// This test suite validates version parsing, comparison, and storage

import XCTest
@testable import FileSystemKit

final class VersionTests: XCTestCase {
    
    // MARK: - VersionParser Tests
    
    func testParseMajorMinor() {
        let components = VersionParser.parse("3.3")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.major, 3)
        XCTAssertEqual(components?.minor, 3)
        XCTAssertNil(components?.patch)
    }
    
    func testParseMajorMinorPatch() {
        let components = VersionParser.parse("2.4.1")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.major, 2)
        XCTAssertEqual(components?.minor, 4)
        XCTAssertEqual(components?.patch, 1)
    }
    
    func testParseWithSuffix() {
        let components = VersionParser.parse("1.0-beta")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.major, 1)
        XCTAssertEqual(components?.minor, 0)
        XCTAssertEqual(components?.suffix, "beta")
    }
    
    func testParseWithBuild() {
        let components = VersionParser.parse("2.3.4+build.123")
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.major, 2)
        XCTAssertEqual(components?.minor, 3)
        XCTAssertEqual(components?.patch, 4)
        XCTAssertEqual(components?.build, "build.123")
    }
    
    func testParseInvalid() {
        let components = VersionParser.parse("invalid")
        XCTAssertNil(components)
    }
    
    func testParseDefault() {
        let components = VersionParser.parse("invalid", defaultMajor: 1, defaultMinor: 0)
        XCTAssertEqual(components.major, 1)
        XCTAssertEqual(components.minor, 0)
    }
    
    // MARK: - VersionComponents Tests
    
    func testVersionComponentsComparison() {
        let v1 = VersionComponents(major: 3, minor: 2)
        let v2 = VersionComponents(major: 3, minor: 3)
        let v3 = VersionComponents(major: 3, minor: 3, patch: 1)
        
        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v2 < v3)
        XCTAssertFalse(v3 < v2)
    }
    
    func testVersionComponentsStringValue() {
        let v1 = VersionComponents(major: 3, minor: 3)
        XCTAssertEqual(v1.stringValue, "3.3")
        
        let v2 = VersionComponents(major: 2, minor: 4, patch: 1)
        XCTAssertEqual(v2.stringValue, "2.4.1")
        
        let v3 = VersionComponents(major: 1, minor: 0, suffix: "beta")
        XCTAssertEqual(v3.stringValue, "1.0-beta")
    }
    
    func testVersionComponentsMajorMinorString() {
        let v1 = VersionComponents(major: 3, minor: 3, patch: 1)
        XCTAssertEqual(v1.majorMinorString, "3.3")
    }
    
    // MARK: - Version Tests
    
    func testVersionInitFromString() {
        let version = Version("3.3", source: "VTOC")
        XCTAssertEqual(version.versionString, "3.3")
        XCTAssertEqual(version.components.major, 3)
        XCTAssertEqual(version.components.minor, 3)
        XCTAssertEqual(version.source, "VTOC")
    }
    
    func testVersionInitFromComponents() {
        let components = VersionComponents(major: 2, minor: 4)
        let version = Version(components: components, source: "Volume Header")
        XCTAssertEqual(version.versionString, "2.4")
        XCTAssertEqual(version.source, "Volume Header")
    }
    
    func testVersionCompare() {
        let v1 = Version("3.2", source: nil)
        let v2 = Version("3.3", source: nil)
        let v3 = Version("3.3", source: nil)
        
        XCTAssertEqual(v1.compare(to: v2), .orderedAscending)
        XCTAssertEqual(v2.compare(to: v1), .orderedDescending)
        XCTAssertEqual(v2.compare(to: v3), .orderedSame)
    }
    
    // MARK: - OperatingSystemVersion Tests
    
    func testOperatingSystemVersionDOS() {
        let version = Version("3.3", source: "VTOC")
        let osVersion = OperatingSystemVersion(fileSystemFormat: .appleDOS33, version: version)
        XCTAssertEqual(osVersion.displayName, "DOS 3.3")
    }
    
    func testOperatingSystemVersionProDOS() {
        let version = Version("2.4", source: "Volume Header")
        let osVersion = OperatingSystemVersion(fileSystemFormat: .proDOS, version: version)
        XCTAssertEqual(osVersion.displayName, "ProDOS 2.4")
    }
    
    func testOperatingSystemVersionWithoutVersion() {
        let osVersion = OperatingSystemVersion(fileSystemFormat: .proDOS, version: nil)
        XCTAssertEqual(osVersion.displayName, "prodos")
    }
    
    // MARK: - ApplicationVersion Tests
    
    func testApplicationVersion() {
        let version = Version("1.0", source: "Metadata")
        let appVersion = ApplicationVersion(
            name: "MyApp",
            version: version,
            publisher: "Acme Corp",
            copyright: "© 2025"
        )
        XCTAssertEqual(appVersion.displayString, "MyApp 1.0")
    }
    
    func testApplicationVersionWithoutVersion() {
        let appVersion = ApplicationVersion(name: "MyApp")
        XCTAssertEqual(appVersion.displayString, "MyApp")
    }
    
    // MARK: - FileVersion Tests
    
    func testFileVersion() {
        let version = Version("2.1", source: "File Header")
        let fileVersion = FileVersion(
            fileName: "PROGRAM",
            version: version,
            fileType: "BIN",
            size: 1024
        )
        XCTAssertEqual(fileVersion.displayString, "PROGRAM v2.1")
    }
    
    func testFileVersionWithoutVersion() {
        let fileVersion = FileVersion(fileName: "PROGRAM")
        XCTAssertEqual(fileVersion.displayString, "PROGRAM")
    }
}

