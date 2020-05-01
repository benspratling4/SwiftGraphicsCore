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
	
}


extension Line {
	
	public func segmentIntersection(with line:Line)->Point? {
		//determine if there is an intersection
		if Triangle(point0: point0, point1: point1, point2: line.point0).isRightHanded == Triangle(point0: point0, point1: point1, point2: line.point1).isRightHanded {
			return nil
		}
		if Triangle(point0: line.point0, point1: line.point1, point2: point0).isRightHanded == Triangle(point0: line.point0, point1: line.point1, point2: point1).isRightHanded {
			return nil
		}
		
		//compute the intersection
		
		let u:Point = Point(x:point1.x - point0.x, y:point1.y - point0.y)
		let v:Point = Point(x:line.point1.x - line.point0.x, y:line.point1.y - line.point0.y)
		let w:Point = Point(x:point0.x - line.point0.x, y:point0.y - line.point0.y)
		
		let scalar:SGFloat = (((v.y)*(w.x)) - ((v.x)*(w.y))) / (((v.x)*(u.y)) - ((v.y)*(u.x)))
		if scalar.isNaN || scalar.isInfinite { return nil }
		return pointAtFraction(scalar)
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
