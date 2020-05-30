//
//  Triangle.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 11/4/17.
//

import Foundation


extension Array where Element == Point {
	
	///assumes the points form a convex hull, left or right handed doesn't matter
	internal var areaOfConvexHull:SGFloat {
		if count < 3 { return 0.0 }
		var area:SGFloat = 0.0
		for i in 1..<count-1 {
			area += Triangle(point0: self[0], point1: self[i], point2: self[i+1]).area
		}
		return area
	}
	
	///given points known to be on a convex hull, order them in the order encounered when walking the hull
	internal var sortedConvexHull:[Point] {
		if count < 4 { return self }
		var remaining:[Point] = self
		let p0:Point = remaining.removeFirst()
		remaining.sort { (p1, p2) -> Bool in
			return Triangle(point0: p0, point1: p1, point2: p2).isRightHanded
		}
		remaining.insert(p0, at: 0)
		return remaining
	}
	
}


public struct Triangle {
	public init(point0:Point, point1:Point, point2:Point) {
		self.point0 = point0
		self.point1 = point1
		self.point2 = point2
	}
	
	public var point0:Point
	public var point1:Point
	public var point2:Point
	
	public var points:[Point] {
		return [point0, point1, point2]
	}
	
	
	public var side0:Line {
		return Line(point0: point0, point1: point1)
	}
	
	public var side1:Line {
		return Line(point0: point1, point1: point2)
	}
	
	public var side2:Line {
		return Line(point0: point2, point1: point0)
	}
	
	public var sides:[Line] {
		return [side0, side1, side2]
	}
	
	public var area:SGFloat {
		let vector0 = point1-point0
		let vector1 = point2-point0
		return abs((vector0.x * vector1.y - vector1.x * vector0.y))/2.0
	}
	
	public var isRightHanded:Bool {
		let vector0 = point1-point0
		let vector1 = point2-point0
		return vector0.x * vector1.y - vector1.x * vector0.y > 0
	}
	
	//flips from left to right handed, or right to left handed
	public var reversed:Triangle {
		return Triangle(point0: point0, point1: point2, point2: point1)
	}
	
	public var rightHanded:Triangle {
		return isRightHanded ? self : reversed
	}
	
	
	public func resequenced(from index:Int)->Triangle {
		switch index {
		case 1:
			return Triangle(point0: point1, point1: point2, point2: point0)
		case 2:
			return Triangle(point0: point2, point1: point0, point2: point1)
		default:
			return self
		}
	}
	
	public func contains(_ point:Point)->Bool {
		let right:Bool = isRightHanded
		return (Triangle(point0: point0, point1: point1, point2: point).isRightHanded == right)
		&& (Triangle(point0: point1, point1: point2, point2: point).isRightHanded == right)
		&& (Triangle(point0: point2, point1: point0, point2: point).isRightHanded == right)
	}
	
	///one triangle contains another if it contains all 3 vertices
	public func contains(_ triangle:Triangle)->Bool {
		return contains(triangle.point0) && contains(triangle.point1) && contains(triangle.point2)
	}
	
	///one triangle likely overlaps another triangle if their bounding boxes intersect with non-zero area
	public func likelyOverlaps(_ triangle:Triangle)->Bool {
		let selfBounds = Rect(bounding: self)
		let otherBounds = Rect(bounding: triangle)
		return (selfBounds.intersection(with: otherBounds)?.area ?? 0.0) > 0.0
	}
	
	///this is a precise measurement, best attempted if its already known they are in proximity to each other
	///return nil if the triangles do not overlap
	public func overlappingArea(of triangle:Triangle)->SGFloat? {
		if !likelyOverlaps(triangle) { return nil }
		
		var pointsOnHull:Set<Point> = Set(self.points.filter({return triangle.contains($0)}))
		pointsOnHull = pointsOnHull.union(Set(triangle.points.filter({return self.contains($0)})))
		let allIntersections:[[Point?]] = self.sides.map({ (side0)->[Point?] in
			return triangle.sides.map({ (side1) -> Point? in
				return side0.segmentIntersection(with:side1)
			})
		})
		let flatIntersections:[Point?] = allIntersections.flatMap({return $0})
		pointsOnHull = pointsOnHull.union(Set(flatIntersections.compactMap({return $0})))
		if pointsOnHull.count < 3 { return nil }
		let hull:[Point] = [Point](pointsOnHull)
		let orderedHull:[Point] = hull.sortedConvexHull
		return orderedHull.areaOfConvexHull
	}
	
	
	var subPath:SubPath {
		var path = SubPath(start: point0)
		path.addLine(to: point1)
		path.addLine(to: point2)
		path.close()
		return path
	}
	
	
	func intersections(line:Line)->[(sideIndex:Int, fraction:SGFloat, coordinates:Point)] {
		return sides.enumerated().compactMap { (sideIndex, side) -> (sideIndex:Int, fraction:SGFloat, coordinates:Point)? in
			guard let fraction = side.fractionOfSegmentIntersection(with:line) else { return nil }
			let coordinates = side.pointAtFraction(fraction)
			return (sideIndex:sideIndex, fraction:fraction, coordinates:coordinates)
		}
	}
	
	
	public var boundingBox:Rect {
		return Rect(boundingPoints: points)
	}
	
}


extension Line {
	
	public func segmentIntersection(with line:Line)->Point? {
		guard let fraction = fractionOfSegmentIntersection(with: line) else { return nil }
		return pointAtFraction(fraction)
	}
	
	public func fractionOfSegmentIntersection(with line:Line)->SGFloat? {
		//based on https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
		let p:Point = point0
		let r:Point = point1 - point0
		let q:Point = line.point0
		let s:Point = line.point1 - line.point0
		let rCrossS:SGFloat = r.crossProductMagnitude(rhs: s)
		let qMinusP:Point = q-p
		let qMinusPCrossR:SGFloat = qMinusP.crossProductMagnitude(rhs: r)
		if rCrossS == 0.0 {
			if qMinusPCrossR != 0 {
				//parallel, non intersecting
				return nil
			}
			//Collinear, express line as an interval on self & look for overlap
			let rDotR:SGFloat = r*r
			let t0:SGFloat = qMinusP*r / rDotR
			let t1:SGFloat = (q+s-p)*r / rDotR
			if s*r < 0 {
				//check if t1...t0 intersects [0, 1]
				if t1 > 1 {
					return nil
				}
				if t0 < 0 {
					return nil
				}
//				let intersectionBottom = max(t1, 0)
				let intersectionTop = min(1, t0)
				return intersectionTop
			}
			//check if t0...t1 intersects [0, 1]
			if t0 > 1 {
				return nil
			}
			if t1 < 0 {
				return nil
			}
//			let intersectionBottom = max(to, 0)
			let intersectionTop = min(1, t1)
			return intersectionTop
		}
		let t:SGFloat = qMinusP.crossProductMagnitude(rhs: s)/rCrossS
		let u:SGFloat = qMinusPCrossR/rCrossS
		if t >= 0.0, t <= 1.0, u >= 0.0, u <= 1 {
			return t
		}
		//not parallel, not intersecting
		return nil
	}
}


extension Transform2D {
	
	public func transform(_ triangle:Triangle)->Triangle {
		return Triangle(point0: transform(triangle.point0), point1: transform(triangle.point1), point2: transform(triangle.point2))
	}
}


extension Rect {
	init(bounding:Triangle) {
		origin = bounding.point0
		size = .zero
		union(bounding.point1)
		union(bounding.point2)
	}
}
