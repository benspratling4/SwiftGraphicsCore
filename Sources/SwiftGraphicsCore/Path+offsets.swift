//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/30/20.
//

import Foundation


enum PathOffsetDirection {
	case left, right
}


extension Path {
	
	func offsetSubpaths(thickness:SGFloat, lineCap:Path.LineCap = .round, join:Path.LineJoin = .round)->Path {
		return Path(subPaths: subPaths.map({ $0.offset(thickness: thickness, lineCap: lineCap, join: join) }))
	}
	
}



extension SubPath {
	
	func offset(thickness:SGFloat, lineCap:Path.LineCap = .round, join:Path.LineJoin = .round)->SubPath {
		if segments.count == 0 {
			switch lineCap {
			case .butt:
				return SubPath(start: start)	//nothing
			case .square:
				return SubPath(inRect: Rect(center: start, size:Size(width: thickness, height: thickness) ))
			case .round:
				return SubPath(ellipseIn:Rect(center: start, size: Size(width: thickness, height: thickness)))
			}
		}
		
		let outLineStart = segments[0].perpendicular(start:start, fraction:0.0, distance:thickness/2.0, direction:.left)
		var outlinePath:SubPath = SubPath(start: outLineStart)
		
		var leftSideSegments:[PathSegment] = []
		var rightSideSegments:[PathSegment] = []
		
		//calculate both left & right side segments
		var previousPreviousStart:Point = start
		var previousStart:Point = start
		var previousSegment:PathSegment?
		for segment in segments {
			let leftSegments:[PathSegment] = segment.offset(start: previousStart, distance: thickness/2.0, direction: .left)
			leftSideSegments.append(contentsOf: leftSegments)
			
			let rightSegments:[PathSegment] = segment.offset(start: previousStart, distance: thickness/2.0, direction: .right)
			
			if let firstSegment = previousSegment {
				//add line join segments
				let leftJoinSegments:[PathSegment] = join.segments(from: previousPreviousStart, firstSegment: firstSegment, secondSegment: segment, offset: thickness/2.0, direction: .left)
				leftSideSegments.append(contentsOf: leftJoinSegments)
				
				let rightJoinSegments:[PathSegment] = join.segments(from: previousPreviousStart, firstSegment: firstSegment, secondSegment: segment, offset: thickness/2.0, direction: .right)
				rightSideSegments.insert(contentsOf: rightJoinSegments, at: 0)
			}
			rightSideSegments.insert(contentsOf: rightSegments, at: 0)
			//ready for next iteration
			previousPreviousStart = previousStart
			previousStart = segment.end
			previousSegment = segment
		}
		
		outlinePath.segments.append(contentsOf:leftSideSegments)
		
		//add endcap
		outlinePath.segments.append(contentsOf:segmentsForEndCap(thickness: thickness, lineCap: lineCap))
		
		//add right-side offsets
		outlinePath.segments.append(contentsOf: rightSideSegments)
		
		//end start cap
		outlinePath.segments.append(contentsOf:segmentsForStartCap(thickness: thickness, lineCap: lineCap))
		
		outlinePath.close()
		return outlinePath
	}
	
	
	///start is from the '.right' side curve
	///assume the point for the end of the right segments is already in the stack
	///dont call if the subpath is closed
	func segmentsForStartCap(thickness:SGFloat, lineCap:Path.LineCap = .round)->[PathSegment] {
		guard let firstSegment:PathSegment = segments.first else { return [] }
		
		switch lineCap {
		case .round:
			let rightOffsetEnd:Point = firstSegment.perpendicular(start: start, fraction: 0.0, distance: thickness/2.0, direction: .right)
			let halfRightDelta:Point = (rightOffsetEnd - start)/2.0
			let leftOffsetEnd:Point = firstSegment.perpendicular(start: start, fraction: 0.0, distance: thickness/2.0, direction: .left)
			let halfLeftDelta:Point = (leftOffsetEnd - start)/2.0
			let (_, derivative) = firstSegment.postionAndDerivative(from: start, fraction: 0.0)
			let antiDerivative:Point = -(thickness/2.0) * derivative / derivative.magnitude
			let endPoint:Point = start + antiDerivative
			return [
				//TODO: fix the control points
				PathSegment(end: start + antiDerivative, shape: .cubic(rightOffsetEnd + antiDerivative/2.0, endPoint + halfRightDelta)),
				PathSegment(end: leftOffsetEnd, shape: .cubic(endPoint + halfLeftDelta, leftOffsetEnd + antiDerivative/2.0)),
			]
			
		case .butt:
			let leftOffsetEnd = firstSegment.perpendicular(start: start, fraction: 0.0, distance: thickness/2.0, direction: .left)
			return [PathSegment(end: leftOffsetEnd, shape: .line)]
			
		case .square:
			let rightOffsetEnd = firstSegment.perpendicular(start: start, fraction: 0.0, distance: thickness/2.0, direction: .right)
			let leftOffsetEnd = firstSegment.perpendicular(start: start, fraction: 0.0, distance: thickness/2.0, direction: .left)
			
			let (_, derivative) = firstSegment.postionAndDerivative(from: start, fraction: 0.0)
			let antiDerivative:Point = -(thickness/2.0) * derivative / derivative.magnitude
			
			return [
				PathSegment(end: rightOffsetEnd + antiDerivative, shape: .line),
				PathSegment(end: leftOffsetEnd + antiDerivative, shape: .line),
				PathSegment(end: leftOffsetEnd, shape: .line),
			]
		}
	}
	
	
	///start is from the '.left' side curve
	///assume the point for the end of the left segments is already in the stack
	///dont call if the subpath is closed
	func segmentsForEndCap(thickness:SGFloat, lineCap:Path.LineCap = .round)->[PathSegment] {
		guard let lastSegment:PathSegment = segments.last else { return [] }
		let previousStart:Point = segments.count > 1 ? segments[segments.count - 2].end : start
		
		switch lineCap {
		case .round:
			let leftOffsetEnd:Point = lastSegment.perpendicular(start: previousStart, fraction: 1.0, distance: thickness/2.0, direction: .left)
			let leftDelta:Point = (leftOffsetEnd - lastSegment.end)/2.0
			let rightOffsetEnd:Point = lastSegment.perpendicular(start: previousStart, fraction: 1.0, distance: thickness/2.0, direction: .right)
			let rightDelta:Point = (rightOffsetEnd - lastSegment.end)/2.0
			let (_, derivative) = lastSegment.postionAndDerivative(from: previousStart, fraction: 1.0)
			let sizedDerivative:Point = (thickness/2.0) * derivative / derivative.magnitude
			let endPoint:Point = lastSegment.end + sizedDerivative
			return [
				PathSegment(end: endPoint, shape: .cubic(leftOffsetEnd + sizedDerivative/2.0, endPoint + leftDelta)),
				PathSegment(end: rightOffsetEnd, shape: .cubic(endPoint + rightDelta, rightOffsetEnd + sizedDerivative/2.0)),
			]
			
		case .butt:
			let rightOffsetEnd = lastSegment.perpendicular(start: previousStart, fraction: 1.0, distance: thickness/2.0, direction: .right)
			return [PathSegment(end: rightOffsetEnd, shape: .line)]
			
		case .square:
			let leftOffsetEnd = lastSegment.perpendicular(start: previousStart, fraction: 1.0, distance: thickness/2.0, direction: .left)
			let rightOffsetEnd = lastSegment.perpendicular(start: previousStart, fraction: 1.0, distance: thickness/2.0, direction: .right)
			
			let (_, derivative) = lastSegment.postionAndDerivative(from: previousStart, fraction: 1.0)
			let sizedDerivative:Point = (thickness/2.0) * derivative / derivative.magnitude
			
			return [
				PathSegment(end: leftOffsetEnd + sizedDerivative, shape: .line),
				PathSegment(end: rightOffsetEnd + sizedDerivative, shape: .line),
				PathSegment(end: rightOffsetEnd, shape: .line),
			]
		}
	}
	
}


extension PathSegment {
	
	func perpendicular(start:Point, fraction:SGFloat, distance:SGFloat, direction:PathOffsetDirection)->Point {
		let (position, derivative) = self.postionAndDerivative(from: start, fraction: fraction)
		let normalizedDerivative:Point = derivative / derivative.magnitude
		let perp:Point
		switch direction {
		case .left:
			perp = Point(x: normalizedDerivative.y, y: -normalizedDerivative.x)
		case .right:
			perp = Point(x:-normalizedDerivative.y, y: normalizedDerivative.x)
		}
		return distance * perp + position
	}
	
	
	func offset(start:Point, distance:SGFloat, direction:PathOffsetDirection)->[PathSegment] {
		switch shape {
		case .line:
			switch direction {
			case .left:
				let destination:Point = perpendicular(start: start, fraction: 1.0, distance: distance, direction: .left)
				return [PathSegment(end: destination, shape: .line)]
				
			case .right:
				let destination:Point = perpendicular(start: start, fraction: 0.0, distance: distance, direction: .right)
				return [PathSegment(end: destination, shape: .line)]
			}
			
		case .quadratic(let control):
			//brute force method, always subdivides at extrema
			var lastEnd:Point = start
			var curveToSubdivide:PathSegment = self
			var earlierCurves:[PathSegment] = []
			while let extrema:SGFloat = curveToSubdivide.nonTerminalExtrema(from: lastEnd).first {
				let (first, second) = curveToSubdivide.subDivide(at: extrema, start: lastEnd)
				earlierCurves.append(first)
				lastEnd = first.end
				curveToSubdivide = second
			}
			earlierCurves.append(curveToSubdivide)
			
			var offsetCurves:[PathSegment] = []
			lastEnd = start
			for curve in earlierCurves {
				let offsetCurve = curve.forcedOffset(start: lastEnd, distance: distance, direction: direction)
					offsetCurves.append(offsetCurve)
				lastEnd = curve.end
			}
			if direction == .left {
				return offsetCurves
			}
			else {
				return offsetCurves.reversed()
			}
			
		case .cubic(let control0, let control1):
			//brute force method, always subdivides at extrema
			var lastEnd:Point = start
			var curveToSubdivide:PathSegment = self
			var earlierCurves:[PathSegment] = []
			while let extrema:SGFloat = curveToSubdivide.nonTerminalExtrema(from: lastEnd).first {
				let (first, second) = curveToSubdivide.subDivide(at: extrema, start: lastEnd)
				earlierCurves.append(first)
				lastEnd = first.end
				curveToSubdivide = second
			}
			earlierCurves.append(curveToSubdivide)
			
			var offsetCurves:[PathSegment] = []
			lastEnd = start
			for curve in earlierCurves {
				let offsetCurve = curve.forcedOffset(start: lastEnd, distance: distance, direction: direction)
					offsetCurves.append(offsetCurve)
				lastEnd = curve.end
			}
			if direction == .left {
				return offsetCurves
			}
			else {
				return offsetCurves.reversed()
			}
		}
	}
	
	//called only to get the offsets of a curve that's already been subdivided
	private func forcedOffset(start:Point, distance:SGFloat, direction:PathOffsetDirection)->PathSegment {
		switch shape {
		case .line:
			fatalError("you don't need this for a line")
		case .quadratic(let control):
			//assuming the curve is flat enough that we can do this
			switch direction {
			case .left:
				let origin:Point = self.perpendicular(start: start, fraction: 0.0, distance: distance, direction: .left)
				let originDelta:Point = origin - start
				let destination:Point = self.perpendicular(start: start, fraction: 1.0, distance: distance, direction: .left)
				let destinationDelta:Point = destination - end
				
				let controlPlusOriginDelta:Point = control + originDelta
				
				let controlPlusDestinationDelta:Point = control + destinationDelta
				
				let offsetLeg0:Line = Line(point0: origin, point1: controlPlusOriginDelta)
				let offsetLeg1:Line = Line(point0: destination, point1: controlPlusDestinationDelta)
				guard let (_, newControl) = offsetLeg0.outOfSegmentIntersectionWithLine(offsetLeg1) else {
					//uh...  why is there no intersection?
					fatalError("write me")
				}
				return PathSegment(end: destination, shape: .quadratic(newControl))
				
			case .right:
				let origin:Point = self.perpendicular(start: start, fraction: 0.0, distance: distance, direction: .right)
				let originDelta:Point = origin - start
				let destination:Point = self.perpendicular(start: start, fraction: 1.0, distance: distance, direction: .right)
				let destinationDelta:Point = destination - end
				let controlPlusOriginDelta:Point = control + originDelta
				
				let controlPlusDestinationDelta:Point = control + destinationDelta
				
				let offsetLeg0:Line = Line(point0: origin, point1: controlPlusOriginDelta)
				let offsetLeg1:Line = Line(point0: destination, point1: controlPlusDestinationDelta)
				guard let (_, newControl) = offsetLeg0.outOfSegmentIntersectionWithLine(offsetLeg1) else {
					//uh...  why is there no intersection?
					fatalError("write me")
				}
				return PathSegment(end: origin, shape: .quadratic(newControl))
			}
			
		case .cubic(let control0, let control1):
			//no non-terminal extrema, flat enough that we can do this
			switch direction {
			case .left:
				let origin = perpendicular(start: start, fraction: 0.0, distance: distance, direction: .left)
				let newEnd = perpendicular(start: start, fraction: 1.0, distance: distance, direction: .left)
				
				let Δorigin:Point = origin - start
				let ΔnewEnd:Point = newEnd - end
				let controlMidLine = PathSegment(end: control1, shape: .line)
				let midLineOffset0 = controlMidLine.perpendicular(start: control0, fraction: 0.0, distance: distance, direction: .left)
				let midLineOffset1 = controlMidLine.perpendicular(start: control0, fraction: 1.0, distance: distance, direction: .left)
				
				let newControlMidLine = Line(point0: midLineOffset0, point1: midLineOffset1)
				
				guard let (_, newControl0) = newControlMidLine.outOfSegmentIntersectionWithLine(Line(point0: origin, point1: control0+Δorigin)) else {
					fatalError("write me")
				}
				guard let (_, newControl1) = newControlMidLine.outOfSegmentIntersectionWithLine(Line(point0: control1+ΔnewEnd, point1: newEnd)) else {
					fatalError("write me")
				}
				return PathSegment(end: newEnd, shape: .cubic(newControl0, newControl1))
				
			case .right:
				let origin = perpendicular(start: start, fraction: 0.0, distance: distance, direction: .right)
				let newEnd = perpendicular(start: start, fraction: 1.0, distance: distance, direction: .right)
				
				let Δorigin:Point = origin - start
				let ΔnewEnd:Point = newEnd - end
				let controlMidLine = PathSegment(end: control1, shape: .line)
				let midLineOffset0 = controlMidLine.perpendicular(start: control0, fraction: 0.0, distance: distance, direction: .right)
				let midLineOffset1 = controlMidLine.perpendicular(start: control0, fraction: 1.0, distance: distance, direction: .right)
				
				let newControlMidLine = Line(point0: midLineOffset0, point1: midLineOffset1)
				
				guard let (_, newControl0) = newControlMidLine.outOfSegmentIntersectionWithLine(Line(point0: origin, point1: control0+Δorigin)) else {
					fatalError("write me")
				}
				guard let (_, newControl1) = newControlMidLine.outOfSegmentIntersectionWithLine(Line(point0: control1+ΔnewEnd, point1: newEnd)) else {
					fatalError("write me")
				}
				return PathSegment(end: origin, shape: .cubic(newControl1, newControl0))
			}
		}
	}
	
}


extension Path.LineJoin {
	
	func segments(from firstSegmentStart:Point, firstSegment:PathSegment, secondSegment:PathSegment, offset:SGFloat, direction:PathOffsetDirection)->[PathSegment] {
		switch self {
		case .bevel:
			switch direction {
			case .left:
				let destination:Point = secondSegment.perpendicular(start: firstSegment.end, fraction: 0.0, distance: offset, direction: .left)
				return [PathSegment(end: destination, shape: .line)]
				
			case .right:
				let destination:Point = firstSegment.perpendicular(start: firstSegmentStart, fraction: 1.0, distance: offset, direction: .right)
				return [PathSegment(end: destination, shape: .line)]
			}
			
		case .round:
			//for now
			return Path.LineJoin.bevel.segments(from: firstSegmentStart, firstSegment: firstSegment, secondSegment: secondSegment, offset: offset, direction: direction)
			//TODO: write me
//			fatalError("write me")
			//TODO: need arbitrary arc code to do this easily
			
		//TODO: add miter case
			
			
		}
	}
	
}
