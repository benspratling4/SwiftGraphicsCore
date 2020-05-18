//
//  File 2.swift
//  
//
//  Created by Ben Spratling on 5/17/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore


class TransformTests : XCTestCase {
	
	func testTranslation() {
		let testCases:[(Point, Transform2D, Point)] = [
			(Point(x: 0.0, y: 1.0), Transform2D(translateX: 0.0, y: 0.0), Point(x: 0.0, y: 1.0)),
			(Point(x:-1.0, y:0.0), Transform2D(translateX: 2.0, y: 3.0), Point(x:1.0, y: 3.0)),
			(Point(x:4.0, y: -1.0), Transform2D(translateX: -2.1, y: 5.3), Point(x: 1.9, y:4.3)),
		]
		
		for testCase in testCases {
			let newPoint:Point = testCase.1.transform(testCase.0)
			XCTAssertEqual(newPoint.x, testCase.2.x, accuracy:0.0001)
			XCTAssertEqual(newPoint.y, testCase.2.y, accuracy:0.0001)
			let untransformed = testCase.1.inverted.transform(newPoint)
			XCTAssertEqual(untransformed.x, testCase.0.x, accuracy:0.0001)
			XCTAssertEqual(untransformed.y, testCase.0.y, accuracy:0.0001)
		}
	}
	
	
	
	func testRotation() {
		//originalPoint, transform, transformedPoint
		let testCases:[(Point, Transform2D, Point)] = [
			(Point(x: 1.0, y: 0.0), Transform2D(rotation:SGFloat.pi / 2), Point(x: 0.0, y: 1.0)),
			(Point(x: 0.0, y: 1.0), Transform2D(rotation:SGFloat.pi / 2), Point(x:-1.0, y: 0.0)),
			(Point(x:-1.0, y: 0.0), Transform2D(rotation:SGFloat.pi / 2), Point(x: 0.0, y:-1.0)),
			(Point(x: 1.0, y: 0.0), Transform2D(rotation:SGFloat.pi / 4), Point(x: 0.707106781186548, y:0.707106781186548)),
		]
		
		for (original, transform, final) in testCases {
			let newPoint:Point = transform.transform(original)
			XCTAssertEqual(newPoint.x, final.x, accuracy:0.0001)
			XCTAssertEqual(newPoint.y, final.y, accuracy:0.0001)
			let untransformed = transform.inverted.transform(newPoint)
			XCTAssertEqual(untransformed.x, original.x, accuracy:0.0001)
			XCTAssertEqual(untransformed.y, original.y, accuracy:0.0001)
		}
	}
	
	func testConcatenation() {
		//finalPoint, transform0, transform1, originalPoint
		//finalPoint == transform0.concatenate(with: transform1).transform(originalPoint)
		//matrix equation finalPoint = transform1 * transform0 * originalPoint
		let testCases:[(Point, Transform2D, Transform2D, Point)] = [
			(Point(x: 24.0, y: 40.0), Transform2D(translateX: 7.0, y: 9.0), Transform2D(scaleX: 3.0, scaleY: 4.0), Point(x: 1.0, y: 1.0)),
			(Point(x: -4, y: 3.0), Transform2D(translateX: 3, y: 4), Transform2D(rotation: SGFloat.pi / 2), Point(x: 0.0, y: 0.0)),
			(Point(x: -2, y: 10.0), Transform2D(rotation: SGFloat.pi / 2), Transform2D(translateX: 2, y: 7), Point(x: 3.0, y: 4.0)),
		]
		
		for (finalPoint, transform0, transform1, originalPoint) in testCases {
			let finalMatrix = transform0.concatenate(with: transform1)
			let calculatedPoint:Point = finalMatrix.transform(originalPoint)
			XCTAssertEqual(calculatedPoint.x, finalPoint.x, accuracy:0.0001)
			XCTAssertEqual(calculatedPoint.y, finalPoint.y, accuracy:0.0001)
			let untransformed = transform1.inverted.concatenate(with: transform0.inverted).transform(calculatedPoint)
			XCTAssertEqual(untransformed.x, originalPoint.x, accuracy:0.0001)
			XCTAssertEqual(untransformed.y, originalPoint.y, accuracy:0.0001)
		}
		
	}
}
