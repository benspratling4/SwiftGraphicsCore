//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/30/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore



class LineIntersectionTests : XCTestCase {
	
	func testOutOfSegmentIntersection() {
		let line0 = Line(point0: Point(x: 0.0, y: 0.0), point1: Point(x: 0.0, y: 1.0))
		let line1 = Line(point0: Point(x: 1.0, y: 2.0), point1: Point(x: 2.0, y: 2.0))
		guard let (fraction, point):(SGFloat, Point) = line0.outOfSegmentIntersectionWithLine(line1) else {
			XCTFail("lines did not intersect")
			return
		}
		XCTAssertEqual(fraction, 2.0)
	}
	
	func testOutOfSegmentIntersection2() {
		let line0 = Line(point0: Point(x: 0.0, y: 0.0), point1: Point(x: 0.0, y: 1.0))
		let line1 = Line(point0: Point(x: 1.0, y: -1.0), point1: Point(x: 2.0, y: -1.0))
		guard let (fraction, point):(SGFloat, Point) = line0.outOfSegmentIntersectionWithLine(line1) else {
			XCTFail("lines did not intersect")
			return
		}
		XCTAssertEqual(fraction, -1.0)
	}
	
	
}
