//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/3/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore




class BezierIntersectionTests : XCTestCase {
	
	
	func testQuadraticTwoIntersections() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: 0.25), point1: Point(x: 1.0, y: 0.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
		
	}
	
	func testQuadraticNoIntersections() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: 1.25), point1: Point(x: 1.0, y: 1.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
		
	}
	
	
	func testQuadraticOneIntersection() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.25, y: 0.0), point1: Point(x: 0.75, y: 1.0))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
		
	}
	
	
	
	
	func testCubicTwoIntersections() {
		//quadraticLike
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), and: Point(x: 0.5, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: 0.25), point1: Point(x: 1.0, y: 0.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
	}
	
	func testCubicTwoIntersections2() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.0, y: 1.0), and: Point(x: 1.0, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: 0.25), point1: Point(x: 1.0, y: 0.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
	}
	
	
	func testCubicTwoOutOfBoundsIntersections() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.0, y: 1.0), and: Point(x: 1.0, y: 1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: -0.25), point1: Point(x: 1.0, y: -0.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
	}
	
	func testCubicOneIntersection() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), and: Point(x: 0.5, y: -1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: -0.5), point1: Point(x: 1.0, y: 0.5))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
	}
	
	func testCubicThreeIntersections() {
		var path = SubPath(start:.zero)
		path.addCurve(near: Point(x: 0.5, y: 1.0), and: Point(x: 0.5, y: -1.0), to: Point(x: 1.0, y: 0.0))
		
		let line = Line(point0: Point(x: 0.0, y: 0.25), point1: Point(x: 1.0, y: -0.25))
		
		let intersections = path.segments[0].intersections(with: line, start:.zero)
		print(intersections)
	}
	
	
	
}
