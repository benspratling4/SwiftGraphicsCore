//
//  Point.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 10/28/17.
//

import Foundation

public struct Point : Hashable {
	public var x:SGFloat
	public var y:SGFloat
	public init(x:SGFloat, y:SGFloat) {
		self.x = x
		self.y = y
	}
	
	
	//Common Constants
	public static let zero:Point = Point(x:0.0, y:0.0)
	
	
	//Self & Float Math
	
	public static func *(lhs:SGFloat, rhs:Point)->Point {
		return Point(x: lhs * rhs.x, y: lhs * rhs.y)
	}
	
	public static func *(lhs:Point, rhs:SGFloat)->Point {
		return Point(x: lhs.x * rhs, y: lhs.y * rhs)
	}
	
	public static func /(lhs:Point, rhs:SGFloat)->Point {
		return Point(x: lhs.x / rhs, y: lhs.y / rhs)
	}
	
	
	//Self & Self Math
	
	public static func +(lhs:Point, rhs:Point)->Point {
		return Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}
	
	public prefix static  func -(lhs:Point)->Point {
		return Point(x: -lhs.x, y: -lhs.y)
	}
	
	public static func -(lhs:Point, rhs:Point)->Point {
		return Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}
	
	public static func +=(lhs:inout Point, rhs:Point) {
		lhs = lhs + rhs
	}
	
	public static func -=(lhs:inout Point, rhs:Point) {
		lhs = lhs - rhs
	}
	
	///dot product, these points are treated as vectors whose origin is .zero
	public static func *(lhs:Point, rhs:Point)->SGFloat {
		return (lhs.x * rhs.x + lhs.y * rhs.y) / (sqrt(lhs.x * lhs.x + lhs.y * lhs.y) * sqrt(rhs.x * rhs.x + rhs.y * rhs.y))
	}
	
	
	//Point & Size Math
	
	public static func +(lhs:Point, rhs:Size)->Point {
		return Point(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
	}
	
	public static func -(lhs:Point, rhs:Size)->Point {
		return Point(x: lhs.x - rhs.width, y: lhs.y - rhs.height)
	}
	
	public static func *(lhs:Point, rhs:Size)->Point {
		return Point(x: lhs.x * rhs.width, y: lhs.y * rhs.height)
	}
	
	public static func /(lhs:Point, rhs:Size)->Point {
		return Point(x: lhs.x / rhs.width, y: lhs.y / rhs.height)
	}
	
	
	//Hashable
	public func hash(into hasher: inout Hasher) {
		x.hash(into: &hasher)
		y.hash(into: &hasher)
	}
	
	
	//Equatable
	
	public static func ==(lhs:Point, rhs:Point)->Bool {
		return lhs.x == rhs.x && lhs.y == rhs.y
	}
	
}
