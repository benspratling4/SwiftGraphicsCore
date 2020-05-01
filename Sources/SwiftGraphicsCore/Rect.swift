//
//  Rect.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 10/28/17.
//

import Foundation


public struct Rect : Hashable {
	public var origin:Point
	public var size:Size
	
	public init(origin:Point, size:Size) {
		self.origin = origin
		self.size = size
	}
	
	public init(center:Point, size:Size) {
		origin = center - size/2.0
		self.size = size
	}
	
	///crash if array has no points
	public init(boundingPoints:[Point]) {
		origin = boundingPoints[0]
		size = .zero
		for point in boundingPoints {
			union(point)
		}
	}
	
	//Computable Properties
	
	/// origin.x + size.width
	public var maxX:SGFloat {
		return origin.x + size.width
	}
	
	/// origin.y + size.height
	public var maxY:SGFloat {
		return origin.y + size.height
	}
	
	public var center:Point {
		return Point(x: origin.x + size.width/2.0, y: origin.y + size.height/2.0)
	}
	
	public var area:SGFloat {
		return size.area
	}
	
	///listed in consecutive order, right handed (in down-facing) way
	public var corners:[Point] {
		return [
			origin,
			Point(x: maxX, y: origin.y),
			Point(x: maxX, y: maxY),
			Point(x: origin.x, y: maxY)
		]
	}
	
	//Obtaining an adjusted rect
	
	/// applies the uniform thicknesses around each corresponding dimension
	/// negative values inset
	public func outset(uniform thickess:Size)->Rect {
		return Rect(origin: origin - thickess, size: size + 2.0 * thickess)
	}
	
	///the rect is rounded out to integral bounds
	public var roundedOut:Rect {
		let newOrigin:Point = Point(x: origin.x.rounded(.down), y: origin.y.rounded(.down))
		let newMaxX:SGFloat = maxX.rounded(.up)
		let newMaxY:SGFloat = maxY.rounded(.up)
		return Rect(origin: newOrigin, size: Size(width: newMaxX-newOrigin.x, height: newMaxY-newOrigin.y))
	}
	
	
	//Overlapping
	
	///returns false for on the edge
	public func contains(_ point:Point)->Bool {
		if point.x <= origin.x
		|| point.y <= origin.y
		|| point.x >= maxX
			|| point.y >= maxY {
			return false
		}
		return true
	}
	
	public func unioning(_ point:Point)->Rect {
		var modified:Rect = self
		modified.union(point)
		return modified
	}
	
	public mutating func union(_ point:Point) {
		if origin.x > point.x {
			size.width += maxX - point.x
			origin.x = point.x
		}
		if origin.y > point.y {
			size.height += maxY - point.y
			origin.y = point.y
		}
		if maxX < point.x {
			size.width = point.x - origin.x
		}
		if maxY < point.y {
			size.height = point.y - origin.y
		}
	}
	
	public func unioning(_ rect:Rect)->Rect {
		var modified:Rect = self
		modified.union(rect)
		return modified
	}
	
	public mutating func union(_ rect:Rect) {
		let maxX:SGFloat = max(self.maxX, rect.maxX)
		let minX:SGFloat = min(origin.x, rect.origin.x)
		let maxY:SGFloat = max(self.maxY, rect.maxY)
		let minY:SGFloat = min(origin.y, rect.origin.y)
		origin = Point(x: minX, y: minY)
		size = Size(width: maxX - minX, height: maxY - minY)
	}
	
	///returns nil if they do not intersect
	public func intersection(with rect:Rect)->Rect? {
		if self.maxX < rect.origin.x
		|| self.maxY < rect.origin.y
		|| origin.x > rect.maxX
			|| origin.y > rect.maxY {
			return nil
		}
		let maxX:SGFloat = min(self.maxX, rect.maxX)
		let minX:SGFloat = max(origin.x, rect.origin.x)
		let maxY:SGFloat = min(self.maxY, rect.maxY)
		let minY:SGFloat = max(origin.y, rect.origin.y)
		return Rect(origin: Point(x: minX, y: minY), size: Size(width: maxX - minX, height: maxY - minY))
	}
	
	
	//Hashable
	
	public func hash(into hasher: inout Hasher) {
		origin.hash(into: &hasher)
		size.hash(into: &hasher)
	}
	
	
	//Equatable
	
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.origin == rhs.origin && lhs.size == rhs.size
	}
	
}
