//
//  SGTransform.swift
//  SwiftGeometry2D
//
//  Created by Ben Spratling on 10/31/17.
//

import Foundation



///Represents an affine transform using homogenous coordinates
/// [ a  b  dx ]   [x]
/// [ c  d  dy ] • [y]
/// [ 0  0  1  ]   [1]
public struct Transform2D {
	public var a:SGFloat
	public var b:SGFloat
	public var c:SGFloat
	public var d:SGFloat
	public var dx:SGFloat
	public var dy:SGFloat
	
	public init(a:SGFloat, b:SGFloat, c:SGFloat, d:SGFloat, dx:SGFloat, dy:SGFloat) {
		self.a = a
		self.b = b
		self.c = c
		self.d = d
		self.dx = dx
		self.dy = dy
	}
	
	public static let identity:Transform2D = Transform2D(a: 1.0, b: 0.0, c: 0.0, d: 1.0, dx: 0.0, dy: 0.0)
	
	public init(scaleX:SGFloat, scaleY:SGFloat) {
		self.a = scaleX
		self.b = 0
		self.c = 0
		self.d = scaleY
		self.dx = 0
		self.dy = 0
	}
	
	///radians, with y going downscreen, positive rotations will look counter-clockwise
	///center is the (0,0) of the current coordinate system
	public init(rotation:SGFloat) {
		self.a = cos(rotation)
		self.b = -sin(rotation)
		self.c = sin(rotation)
		self.d = cos(rotation)
		self.dx = 0
		self.dy = 0
	}
	
	public init(translateX:SGFloat, y:SGFloat) {
		self.a = 1
		self.b = 0
		self.c = 0
		self.d = 1
		self.dx = translateX
		self.dy = y
	}
	
	///x and y are angles in radians
	///center is the (0,0) of the current coordinate system
	public init(skewAngleX:SGFloat, y:SGFloat) {
		self.init(skewX: tan(skewAngleX), y: tan(y))
	}
	
	///x and y are change in x or y per other unit
	///center is the (0,0) of the current coordinate system
	public init(skewX:SGFloat, y:SGFloat) {
		self.a = 1
		self.b = y
		self.c = skewX
		self.d = 1
		self.dx = 0.0
		self.dy = 0.0
	}
	
	public func transform(_ point:Point)->Point {
		return Point(x: a * point.x + b * point.y + dx, y:c*point.x + d*point.y + dy)
	}
	
	public func transform(_ path:Path)->Path {
		return Path(subPaths: path.subPaths.map({ transform($0) }))
	}
	
	internal func transform(_ subPath:SubPath)->SubPath {
		return SubPath(segments: subPath.segments.map({ transform($0) }))
	}
	
	internal func transform(_ segment:PathSegment)->PathSegment {
		switch segment.shape {
		case .point:
			return PathSegment.init(end: transform(segment.end), shape: .point)
		case .line:
			return PathSegment.init(end: transform(segment.end), shape: .line)
			
		case .quadratic(let control):
			return PathSegment.init(end: transform(segment.end), shape: .quadratic(transform(control)))
			
		case .cubic(let control0, let control1):
			return PathSegment.init(end: transform(segment.end), shape: .cubic(transform(control0), transform(control1)))
		}
	}
	
	///coordinates will be transformed as in self.concatenate(with:otherTransform).transform(point) ==  otherTransform.transform(self.transform(point))
	///in other words if you have the matrix equation v = M A x, then that's v = A.concatenate(M).transform(x) 
	public func concatenate(with otherTransform:Transform2D)->Transform2D {
		let m:Transform2D = otherTransform
		return Transform2D(a: m.a * a + m.b*c
			,b: m.a*b + m.b*d
			,c: m.c*a + m.d*c
			,d: m.c*b + m.d*d
			,dx: m.a*dx + m.b*dy + m.dx
			,dy: m.c*dx + m.d*dy + m.dy)
	}
	
	public var inverted:Transform2D {
		let determinant:SGFloat = a*d - b*c
		return Transform2D(a: d / determinant
			,b: -b/determinant
			,c: -c/determinant
			,d: a/determinant
			,dx:(b*dy - d*dx)/determinant
			,dy:(c*dx - a*dy)/determinant)
	}
	
}
