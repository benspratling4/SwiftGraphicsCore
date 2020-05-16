//
//  BezierBoundingBoxTests.swift
//  
//
//  Created by Ben Spratling on 5/16/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore


class BezierBoundingBoxTests : XCTestCase {
	
	func testRectUnion() {
		var rect = Rect(origin: .zero, size: Size(width: 1.0, height: 1.0))
		rect.union(Point(x: 2.0, y: 0.0))
		XCTAssertEqual(rect.size.width, 2.0)
	}
	
	func testQuadraticBoundingBox() {
		var path = Path()
		path.move(to: Point(x: 0.0, y: 0.0))
		path.addCurve(near: Point(x: 1.0, y: 2.0), to: Point(x: 2.0, y: 0.0))
		guard let box = path.boundingBox else {
			XCTFail("did not create bouding box")
			return
		}
		XCTAssertEqual(box.size.width, 2.0, accuracy:0.00001)
		XCTAssertEqual(box.size.height, 1.0, accuracy:0.00001)
	}
	
	func testQuadraticBoundingBox2() {
		var path = Path()
		path.move(to: Point(x: 2.0, y: 0.0))
		path.addCurve(near: Point(x: 0.0, y: 1.0), to: Point(x: 2.0, y: 2.0))
		guard let box = path.boundingBox else {
			XCTFail("did not create bouding box")
			return
		}
		XCTAssertEqual(box.origin.x, 1.0, accuracy:0.00001)
		XCTAssertEqual(box.size.width, 1.0, accuracy:0.00001)
	}
	
	
	
}


