//
//  Bezier.swift
//  SwiftPNG
//
//  Created by Ben Spratling on 10/31/17.
//

import Foundation


public struct Path {
	public var subPaths:[SubPath]
	
	public init(subPaths:[SubPath]) {
		self.subPaths = subPaths
	}
	
	//TODO: how do these subpaths combine?
}



///Simple Bezier Path
public struct SubPath {
	public var segments:[PathSegment] = []
	
	//public var closed:Bool = false
	public init(startingPoint:Point) {
		segments = [.init(end: startingPoint, shape: .point)]
	//	closed = false
	}
	
	public mutating func move(to point:Point) {
		segments.append(.init(end: point, shape: .point))
	}
	
	public mutating func addLine(to point:Point) {
		segments.append(.init(end: point, shape: .line))
	}
	
	public mutating func addCurve(near controlPoint:Point, to point:Point) {
		segments.append(.init(end: point, shape: .quadratic(controlPoint)))
	}
	
	public mutating func addCurve(near controlPoint:Point, and controlPoint2:Point, to point:Point) {
		segments.append(.init(end: point, shape: .cubic(controlPoint, controlPoint2)))
	}
	
	
	public init(inRect:Rect) {
		segments = [.init(end: inRect.origin, shape: .point)
			,.init(end: inRect.origin + Point(x: inRect.size.width, y: 0.0), shape: .line)
			,.init(end: inRect.origin + Point(x: inRect.size.width, y: inRect.size.height), shape: .line)
			,.init(end: inRect.origin + Point(x: 0.0, y: inRect.size.height), shape: .line)
			,.init(end: inRect.origin, shape: .line)
		]
	}
	
	///does not assume path is closed.
	///assumes all segments are lines, not curves
	public func isPoint(_ point:Point, within distance:SGFloat)->Bool {
		if segments.count == 0 {
			return false
		}
		if segments.count == 1 {
			return Line(point0: segments[0].end, point1: point).length <= distance
		}
		var lastEnd:Point = segments[0].end
		for i in 1..<segments.count {
			let newEnd:Point = segments[i].end
			defer {
				lastEnd = newEnd
			}
			let line:Line = Line(point0: lastEnd, point1: newEnd)
			let (nearest, fraction) = line.nearestPoint(to:point)
			if fraction < 0.0 || fraction > 1.0 {
				//check proximity to endpoints
				//this makes rounded endpoints & joints
				if Line(point0: line.point0, point1: point).length <= distance {
					return true
				}
				if Line(point0: line.point1, point1: point).length <= distance {
					return true
				}
				continue
			}
			if Line(point0: nearest, point1: point).length <= distance {
				return true
			}
		}
		return false
	}
	
	
	public var boundingBox:Rect {
		if segments.count < 1 {
			return Rect(origin: .zero, size: .zero)
		}
		var bounds:Rect = Rect(origin: segments[0].end, size: .zero)
		for segment in segments {
			bounds.union(segment.end)
		}
		return bounds
	}
	
	
	///		///precise calculation, imprecise exclusion provided by the overestimatedConvexHull
	/// currently assumes the edges are all lines...  oh well.
	///have not tested subpaths
	public func contains(_ point:Point)->Bool {
		if segments.count < 2 {
			return false
		}
		var endPoints:[Point] = segments.map({ return $0.end })
		endPoints.append(segments[0].end)
		var lastEndPoint:Point = endPoints[0]
		var windingCount:Int = 0
		for index in 1..<endPoints.count {
			let end:Point = endPoints[index]
			defer {
				lastEndPoint = end
			}
			if lastEndPoint == end {
				continue
			}
			let segment:Line = Line(point0: lastEndPoint, point1: end)
			switch (segment.point0.y<point.y, segment.point1.y<point.y) {
			case (true, true):
				fallthrough
			case (false, false):
				continue
			case (true, false):
				switch segment.shortestAngularDirectionTowardPoint(point) {
				case .same:
					continue
				case .clockwise:
					windingCount += 1
				case .counterclockwise:
					//ignore, it's on the other side
					continue
				}
			case (false, true):
				switch segment.shortestAngularDirectionTowardPoint(point) {
				case .same:
				continue
				case .clockwise:
					//ignore
					continue
				case .counterclockwise:
					windingCount -= 1
				}
			}
		}
		
		return windingCount != 0
	}
	
	
}

public struct PathSegment {
	
	public var end:Point
	public var shape:Shape
	
	///all shapes, except for point, assume a starting point of the previous endPoint
	public enum Shape {
		case point
		
		case line
		///control point
		case quadratic(Point)
		///controls points
		case cubic(Point, Point)
		
		//TODO: pure ellipsoidal arc
	}
	
	internal init(end:Point, shape:Shape) {
		self.end = end
		self.shape = shape
	}
	
	
	public func postion(from start:Point, fraction:SGFloat)->Point {
		return postionAndDerivative(from: start, fraction: fraction).0
	}
	
	///returns the point on the segment at the given percentage, and also the direction in which the line is traveling
	///the direction will not be normalized, and may not be non-zero
	public func postionAndDerivative(from start:Point, fraction:SGFloat)->(Point, Point) {
		switch shape {
		case .point:
			return (end, end-start)
		case .line:
			let line:Line = Line(point0: start, point1: end)
			return (line.pointAtFraction(fraction), end-start)
			
		case .quadratic(let control):
			let controlLine0:Line = Line(point0: start, point1: control)
			let controlLine1:Line = Line(point0: control, point1: end)
			let halfStart:Point = controlLine0.pointAtFraction(fraction)
			let halfEnd:Point = controlLine1.pointAtFraction(fraction)
			let halfLine:Line = Line(point0: halfStart, point1: halfEnd)
			let point:Point = halfLine.pointAtFraction(fraction)
			return (point, halfEnd-halfStart)
			
		case .cubic(let control0, let control1):
			let controlLine0:Line = Line(point0: start, point1: control0)
			let controlLine1:Line = Line(point0: control1, point1: end)
			let controlConnecter:Line = Line(point0: control0, point1: control1)
			let connectorCenter:Point = controlConnecter.pointAtFraction(fraction)
			let half0:Line = Line(point0: controlLine0.pointAtFraction(fraction), point1: connectorCenter)
			let half1:Line = Line(point0: connectorCenter, point1: controlLine1.pointAtFraction(fraction))
			let finalBar = Line(point0: half0.pointAtFraction(fraction), point1: half1.pointAtFraction(fraction))
			let point = finalBar.pointAtFraction(fraction)
			return (point, finalBar.point1 - finalBar.point0)
		}
	}
	
	/// De Casteljau subdivision for bezier curves
	///this segment can be replaced by the two segments in the result
	public func subDivide(at fraction:SGFloat, start:Point)->(PathSegment, PathSegment) {
		switch shape {
		case .point:
			return (.init(end:start, shape:.point), .init(end:end, shape:.point))
			
		case .line:
			let line:Line = Line(point0: start, point1: end)
			let midPoint:Point = line.pointAtFraction(fraction)
			return (.init(end:midPoint, shape:.line), .init(end:end, shape:.line))
			
		case .quadratic(let control):
			let controlLine0:Line = Line(point0: start, point1: control)
			let controlLine1:Line = Line(point0: control, point1: end)
			let halfStart:Point = controlLine0.pointAtFraction(fraction)
			let halfEnd:Point = controlLine1.pointAtFraction(fraction)
			let halfLine:Line = Line(point0: halfStart, point1: halfEnd)
			let point:Point = halfLine.pointAtFraction(fraction)
			return (.init(end:point, shape:.quadratic(halfStart)), .init(end:end, shape:.quadratic(halfEnd)))
			
		case .cubic(let control0, let control1):
			let controlLine0:Line = Line(point0: start, point1: control0)
			let controlLine1:Line = Line(point0: control1, point1: end)
			let controlConnecter:Line = Line(point0: control0, point1: control1)
			let connectorCenter:Point = controlConnecter.pointAtFraction(fraction)
			let half0:Line = Line(point0: controlLine0.pointAtFraction(fraction), point1: connectorCenter)
			let half1:Line = Line(point0: connectorCenter, point1: controlLine1.pointAtFraction(fraction))
			let finalBar = Line(point0: half0.pointAtFraction(fraction), point1: half1.pointAtFraction(fraction))
			let point = finalBar.pointAtFraction(fraction)
			return (.init(end:point, shape:.cubic(half0.point0, finalBar.point0)), .init(end:end, shape:.cubic(finalBar.point1, half1.point1)))
		}
	}
	
	
	

}

