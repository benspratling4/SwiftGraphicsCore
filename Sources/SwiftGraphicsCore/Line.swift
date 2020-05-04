//
//  Line.swift
//  SwiftGeometry2D
//
//  Created by Ben Spratling on 11/2/17.
//

import Foundation

public struct Line {
	public var point0:Point
	public var point1:Point
	
	public init(point0:Point, point1:Point) {
		self.point0 = point0
		self.point1 = point1
	}
	
	public func pointAtFraction(_ fraction:SGFloat)->Point {
		let diff:Point = point1 - point0
		let scaledDiff:Point = diff * fraction
		return point0 + scaledDiff
	}
	
	public var length:SGFloat {
		let diff:Point = point1 - point0
		return sqrt((diff.x * diff.x) + (diff.y * diff.y))
	}
	
	public func intersectionWithLine(_ otherLine:Line)->Point? {
		guard let (point, _):(Point, SGFloat) = intersectionWithLine(otherLine) else {
			return nil
		}
		return point
	}
	
	///If slopes are equal, but not coincident, there is no intersection
	///since the intended application is looking for generally perpendicular lines, this math case is not considered
	public func intersectionWithLine(_ otherLine:Line)->(Point, SGFloat)? {
		
		let u:Point = Point(x:point1.x - point0.x, y:point1.y - point0.y)
		let v:Point = Point(x:otherLine.point1.x - otherLine.point0.x, y:otherLine.point1.y - otherLine.point0.y)
		let w:Point = Point(x:point0.x - otherLine.point0.x, y:point0.y - otherLine.point0.y)
		
		//TODO: detect coincident and parrallel lines
		
		
		let scalar:SGFloat = (((v.y)*(w.x)) - ((v.x)*(w.y))) / (((v.x)*(u.y)) - ((v.y)*(u.x)))
		if scalar.isNaN || scalar.isInfinite { return nil }
		return (pointAtFraction(scalar), scalar)
	}
	
	/// return the point on the line closest to the given point, and the fractional position along the line
	public func nearestPoint(to point:Point)->(Point, SGFloat) {
		//construct a perpendicular line through the given point, return the intersection
		let vector:Point = point1 - point0
		let perpendicular:Point = Point(x: -vector.y, y: vector.x)
		let perpendicularLine:Line = Line(point0: point, point1: point + perpendicular)
		guard let (intersection, fraction):(Point, SGFloat) = intersectionWithLine(perpendicularLine) else {
			//we forced the line to be perpendicular, so this can't happen, unless the original line isn't a line...
			let pointDistance:SGFloat = Line(point0: point0, point1: point).length / length
			return (point, pointDistance)
		}
		return (intersection, fraction)
	}
	
	///if this point is actually ON the line, then it reports the fraction
	public func intersection(with point:Point, tolerance:SGFloat = 0.0001)->SGFloat? {
		if Line(point0: point, point1: point0).length <= tolerance {
			return 0.0
		}
		if Line(point0: point, point1: point1).length <= tolerance {
			return 1.0
		}
		let vector:Point = point1 - point0
		let perpendicular:Point = Point(x: -vector.y, y: vector.x)
		let perpendicularLine:Line = Line(point0: point, point1: point + perpendicular)
		guard let (intersection, fraction):(Point, SGFloat) = intersectionWithLine(perpendicularLine) else {
			return nil
		}
		
		guard Line(point0: intersection, point1: point).length <= tolerance else {
			return nil
		}
		return fraction
	}
	
	//returns the nearest point, and its distance
	public func distanceToNearestPoint(_ point:Point)->SGFloat {
		let (foundPoint, _) = nearestPoint(to: point)
		return Line(point0: point, point1: foundPoint).length
	}
	
	public enum AngularDirection {
		case clockwise, same, counterclockwise
		
		public static prefix func -(lhs:AngularDirection)->AngularDirection {
			switch lhs {
			case .same:
				return .same
			case .clockwise:
				return .counterclockwise
			case .counterclockwise:
				return .clockwise
			}
		}
	}
	
	///results are oriented for a y-positive = down screen result
	public func shortestAngularDirectionTowardPoint(_ point:Point)->AngularDirection {
		let determinant:SGFloat = ((point1.x-point0.x) * (point.y-point0.y)) - ((point.x-point0.x) * (point1.y-point0.y))
		if determinant == 0.0 {
			return .same
		}
		if determinant > 0 {
			return .clockwise
		}
		return .counterclockwise
	}
	
	
}

/// Computes the intersection
public func &&(line0:Line, line1:Line)->Point? {
	return line0.intersectionWithLine(line1)
}

