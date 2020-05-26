//
//  Bezier.swift
//  SwiftPNG
//
//  Created by Ben Spratling on 10/31/17.
//

import Foundation

//lots of usful stuff https://pomax.github.io/bezierinfo/#derivatives


public struct Path {
	
	public enum SubPathOverlapping {
		///if a point is inside an odd number of subpaths, it is "in", if inside an even number of subpaths, it is "out".
		///This is the default case, and allows for subpaths to provide "cut outs"
		case evenOdd
		
		///if a point is inside any subpath, it is "in".  This makes multiple subpaths always additive, regardless of the directions of the path segments
		case nonZero
		
		/// a point is "inside" if there are more +y-direction path crossings to the left of the the point than -y-direction path crossings
		///for instance, this is the way TTF font files determine their "inside"
		case windingNumber // not currently supported
		
		func contains(intersectionCount:Int)->Bool {
			switch self {
			case .evenOdd:
				return intersectionCount%2 != 0
				
			case .nonZero:
				return intersectionCount != 0
				
			case .windingNumber:
				return intersectionCount != 0
			}
		}
		
	}
	
	
	public enum LineCap {
		///the line ends as if there were a circle of linethickness centered on the endpoint
		case round
		
		///the line ends at the point, with a line perpendicular to the slope at that point
		///not supported
//		case butt
		
		///not supported
//		case square
	}
	
	public enum LineJoin {
		///the vertexes between segments are treated as if circles were centered on them
		case round
		
		///not supported
//		case miter(limit:SGFloat?)
		
		///not supported
//		case bevel
	}
	
	public var subPaths:[SubPath]
	
	public init(subPaths:[SubPath] = []) {
		self.subPaths = subPaths
	}
	
	public func contains(_ point:Point, overlapping:SubPathOverlapping = .evenOdd)->Bool {
		switch overlapping {
		case .evenOdd:
			let hitCount:Int = subPaths.filter({ $0.contains(point, overlapping: overlapping) }).count
			return hitCount % 2 != 0
		case .nonZero:
			return subPaths.map({$0.contains(point, overlapping: overlapping)}).reduce(false, { $0 || $1 })
		case .windingNumber:
			//TODO: write me
			fatalError("write me")
		}
	}
	
	
	public func intersectionCountFromNegativeInfinityX(_ point:Point, overlapping:SubPathOverlapping = .evenOdd)->Int {
		var count:Int = 0
		for subPath in subPaths {
			count += subPath.intersectionCountFromNegativeInfinityX(point, overlapping: overlapping)
		}
		return count
	}
	
	public func isPoint(_ point:Point, within distance:SGFloat, cap:LineCap = .round, join:LineJoin = .round)->Bool {
		return subPaths.map({ $0.isPoint(point, within:distance, cap: cap, join:join) }).reduce(false, { $0 || $1 })
	}
	
	public mutating func move(to point:Point) {
		subPaths.append(SubPath(start: point))
	}
	
	public func byMoving(to point:Point)->Path {
		var newPath = self
		newPath.move(to: point)
		return newPath
	}
	
	public mutating func addLine(to point:Point) {
		guard subPaths.count > 0 else { return }
		subPaths[subPaths.count-1].addLine(to: point)
	}
	
	public func byAddingLine(to point:Point)->Path {
		var newPath = self
		newPath.addLine(to: point)
		return newPath
	}
	
	public mutating func addCurve(near controlPoint:Point, to point:Point) {
		guard subPaths.count > 0 else { return }
		subPaths[subPaths.count-1].addCurve(near: controlPoint, to: point)
	}
	
	public func byAddingCurve(near controlPoint:Point, to point:Point)->Path {
		var newPath = self
		newPath.addCurve(near: controlPoint, to: point)
		return newPath
	}
	
	public mutating func addCurve(near controlPoint:Point, and controlPoint2:Point, to point:Point) {
		guard subPaths.count > 0 else { return }
		subPaths[subPaths.count-1].addCurve(near: controlPoint, and: controlPoint2, to: point)
	}
	
	public func byAddingCurve(near controlPoint:Point, and controlPoint2:Point, to point:Point)->Path {
		var newPath = self
		newPath.addCurve(near: controlPoint, and: controlPoint2, to: point)
		return newPath
	}
	
	public mutating func close() {
		guard subPaths.count > 0 else { return }
		subPaths[subPaths.count-1].close()
	}
	
	public func byClosing()->Path {
		var newPath = self
		newPath.close()
		return newPath
	}
	
	public init(inRect:Rect) {
		self.subPaths = [
			SubPath(inRect: inRect)
		]
	}
	
	///tight box
	public var boundingBox:Rect? {
		guard subPaths.count > 0 else { return nil }
		var box:Rect = subPaths[0].boundingBox
		for i in 1..<subPaths.count {
			box = box.unioning(subPaths[i].boundingBox)
		}
		return box
	}
	
	///rect containing all start, end, control points
	public var fastBoundingBox:Rect? {
		guard subPaths.count >= 0 else { return nil }
		var box:Rect = subPaths[0].fastBoundingBox
		for i in 1..<subPaths.count {
			box = box.unioning(subPaths[i].fastBoundingBox)
		}
		return box
	}
	
	///subdivides each segment until its deviation from a straight line is less than the indicated amount
	public func subDivided(linearity:SGFloat)->Path {
		return Path(subPaths: subPaths.map({$0.subDivided(linearity: linearity)}))
	}
	
	///replaces quadratic and cubic segments with lines with the same endpoints
	public func replacingWithLines()->Path {
		return Path(subPaths: subPaths.map({$0.replacingWithLines()}))
	}
	
	///if any subpath has an end coordinate that is not the start coordinate, this closes it
	///this is necessary for, for instance, fill algorithms which require explicit segments on the close line
	public func explicitlyClosingAllSubpaths()->Path {
		return Path(subPaths: subPaths.map({ $0.byExplicitlyClosing() }))
	}
}


///Simple Bezier Path
public struct SubPath {
	public var start:Point
	public var segments:[PathSegment] = []
	public var closed:Bool
	//in the next breaking version, remove the .point shape, and always have a start point for a SubPath, then introduce a boolean for whether the subPath is closed.
	public init(start:Point, segments:[PathSegment] = [], closed:Bool = false) {
		self.start = start
		self.segments = segments
		self.closed = closed
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
	
	public mutating func close() {
		closed = true
	}
	
	public init(inRect:Rect) {
		start = inRect.origin
		segments = [
			.init(end: inRect.origin + Point(x: inRect.size.width, y: 0.0), shape: .line)
			,.init(end: inRect.origin + Point(x: inRect.size.width, y: inRect.size.height), shape: .line)
			,.init(end: inRect.origin + Point(x: 0.0, y: inRect.size.height), shape: .line)
		]
		closed = true
	}
	
	public func isPoint(_ point:Point, within distance:SGFloat, cap:Path.LineCap = .round, join:Path.LineJoin = .round)->Bool {
		if Line(point0: start, point1: point).length <= distance {
			//assumes cap == .round
			return true
		}
		var lastEnd:Point = start
		for segment in segments {
			let newEnd:Point = segment.end
			defer {
				lastEnd = newEnd
			}
			//check if it's within the distance from a bounding box
			let fastBoudingRect:Rect = segment.fastBoundingBox(from:lastEnd)
			if !fastBoudingRect.outset(uniform:Size(width: distance, height: distance)).contains(point) {
				continue
			}
			//and a narrower bouding box
//			let boudingRect:Rect = segment.boundingBox(from:lastEnd)
//			if boudingRect.outset(uniform:Size(width: distance, height: distance)).contains(point) {
				if segment.isPoint(point, within: distance, start: lastEnd, cap: cap, join:join) {
					return true
				}
//			}
		}
		if closed, let lastSegmentEnd:Point = segments.last?.end {
			let fauxSegment = PathSegment(end: start, shape: .line)
			return fauxSegment.isPoint(point, within: distance, start: lastSegmentEnd, cap: cap, join: join)
		}
		return false
	}
	
	///tight fit
	public var boundingBox:Rect {
		var bounds:Rect = Rect(origin: start, size: .zero)
		var previousEnd:Point = start
		for segment in segments {
			bounds.union(segment.boundingBox(from: previousEnd))
			previousEnd = segment.end
		}
		return bounds
	}
	
	///loose fit, includes control points
	public var fastBoundingBox:Rect {
		var bounds:Rect = Rect(origin: start, size: .zero)
		var previousEnd:Point = start
		for segment in segments {
			bounds.union(segment.fastBoundingBox(from: previousEnd))
			previousEnd = segment.end
		}
		return bounds
	}
	
	
	public func subDivided(linearity:SGFloat)->SubPath {
		var newSegments:[PathSegment] = []
		var previousEnd:Point = start
		for segment in segments {
			newSegments.append(contentsOf: segment.subDivided(from:previousEnd, linearity: linearity))
			previousEnd = segment.end
		}
		return SubPath(start:start, segments:newSegments, closed:closed)
	}
	
	
	public func replacingWithLines()->SubPath {
		var newSegments:[PathSegment] = []
		var previousEnd:Point = start
		for segment in segments {
			newSegments.append(segment.replacingWithLines(from: previousEnd))
			previousEnd = segment.end
		}
		if closed, previousEnd != start {
			newSegments.append(PathSegment(end: start, shape: .line))
		}
		return SubPath(start:start, segments:newSegments, closed: closed)
	}
	
	
	public func byExplicitlyClosing()->SubPath {
		if closed {
			return self
		}
		return SubPath(start:start, segments: segments, closed: true)
	}
	
	
	
	///		///precise calculation, imprecise exclusion provided by the overestimatedConvexHull
	/// currently assumes the edges are all lines...  oh well.
	///have not tested subpaths
	public func contains(_ point:Point, overlapping:Path.SubPathOverlapping)->Bool {
		if segments.count < 2 {
			return false
		}
		var previousStart:Point = segments[0].end
		var runningCount:Int = 0
		for segmentIndex in 1..<segments.count {
			let segment = segments[segmentIndex]
			runningCount += segment.intersectionCountFromNegativeInfinityX(at: point, from: previousStart, overlapping: overlapping)
			previousStart = segment.end
		}
		switch overlapping {
		case .evenOdd:
			return runningCount % 2 != 0
		case .nonZero:
			fatalError("write me")	//what is this?
		case .windingNumber:
			return runningCount != 0
		}
		
	}
	
	
	public func intersectionCountFromNegativeInfinityX(_ point:Point, overlapping:Path.SubPathOverlapping)->Int {
		var count:Int = 0
		var previousPoint:Point = start
		for segment in segments {
			count += segment.intersectionCountFromNegativeInfinityX(at: point, from: previousPoint, overlapping: overlapping)
			previousPoint = segment.end
		}
		return count
	}
 
	//TODO: write me supports being able to split curves
//	func intersection(rect:Rect)->SubPath? {
//
//	}
	
}

public struct PathSegment {
	//in the next breaking version, remove the .point shape, and always have a start point for a SubPath, then introduce a boolean for whether the subPath is closed.
	public var end:Point
	public var shape:Shape
	
	///all shapes, except for point, assume a starting point of the previous endPoint
	public enum Shape {
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
	
	
	public func boundingBox(from start:Point)->Rect {
		var points:[Point] = [start, end]
		points.append(contentsOf: nonTerminalExtrema(from: start).map({ position(from: start, fraction: $0) }))
		return Rect(boundingPoints: points)
	}
	
	
	public func fastBoundingBox(from start:Point)->Rect {
		switch shape {
		case .line:
			return Rect(boundingPoints: [start, end])
		case .quadratic(let control):
			return Rect(boundingPoints: [start, control, end])
		case .cubic(let control0, let control1):
			return Rect(boundingPoints: [start, control0, control1, end])
		}
	}
	
	///returns an array of fractional values of the non-terminal extrema
	public func nonTerminalExtrema(from start:Point)->[SGFloat] {
		switch shape {
		case .line:
			return []	//never any non-terminal extrema
			
		case .quadratic(let control):
			var extrema:[SGFloat] = []
			let xExtremaDenominator:SGFloat = (end.x - control.x)-(control.x - start.x)
			if xExtremaDenominator != 0.0 {
				let tAtxExtrema:SGFloat = -(control.x - start.x) / xExtremaDenominator
				if tAtxExtrema > 0, tAtxExtrema < 1 {
					extrema.append(tAtxExtrema)
				}
			}
			let yExtremaDenominator:SGFloat = (end.y - control.y)-(control.y - start.y)
			if yExtremaDenominator != 0.0 {
				let tAtyExtrema:SGFloat = -(control.y - start.y) / yExtremaDenominator
				if tAtyExtrema > 0, tAtyExtrema < 1 {
					extrema.append(tAtyExtrema)
				}
			}
			return extrema
			
		case .cubic(let control0, let control1):
			let (cx3, cx2, cx1, _) = bezierCoefficients(P0: start.x, P1: control0.x, P2: control1.x, P3: end.x)
			let (cy3, cy2, cy1, _) = bezierCoefficients(P0: start.y, P1: control0.y, P2: control1.y, P3: end.y)
			let solutions:[SGFloat] = realQuadraticRoots(a: 3.0*cx3, b: 2.0*cx2, c: cx1) + realQuadraticRoots(a: 3.0*cy3, b:2.0*cy2, c: cy1)
			return solutions.filter({ $0 > 0.0 && $0 < 1.0 })
		}
	}
	
	public func maxDeviationsFromLinearity(from start:Point)->[(fraction:SGFloat, distance:SGFloat)] {
		let transformedSegment:PathSegment
		let unTransformedEnd:Point
		switch shape {
		case .line:
			return []
		case .quadratic(let control):
			//create a new segment, aligned to the x axis
			let centeredEnd:Point = Point(x: end.x-start.x, y: end.y - start.y)
			//now rotate the path such that the end point lines on y = 0, x >= 0
			
			if centeredEnd.x == 0, centeredEnd.y == 0 {
				//we can't rotate it
				transformedSegment = PathSegment(end: end - start, shape: .quadratic(control-start))
				unTransformedEnd = centeredEnd
			} else {
				//now find a transformation matrix that rotates that point to y = 0 x >= 0
				let endMagnitude:SGFloat = sqrt(centeredEnd.x*centeredEnd.x + centeredEnd.y*centeredEnd.y)
				let normalizedCenteredEnd:Point = centeredEnd / endMagnitude
				let unRotating:Transform2D = Transform2D(a: normalizedCenteredEnd.x, b: normalizedCenteredEnd.y, c:-normalizedCenteredEnd.y, d: normalizedCenteredEnd.x, dx: 0.0, dy: 0.0)
				let finalTransform:Transform2D = Transform2D(translateX: -start.x, y: -start.y).concatenate(with: unRotating)
				let unTransformControl:Point = finalTransform.transform(control)
				unTransformedEnd = finalTransform.transform(end)
				transformedSegment = PathSegment(end: unTransformedEnd, shape: .quadratic(unTransformControl))
			}
			
		case .cubic(let control0, let control1):
			//create a new segment, aligned to the x axis
			let centeredEnd:Point = Point(x: end.x-start.x, y: end.y - start.y)
			//now rotate the path such that the end point lines on y = 0, x >= 0
			
			if centeredEnd.x == 0, centeredEnd.y == 0 {
				//we can't rotate it
				transformedSegment = PathSegment(end: end - start, shape: .cubic(control0 - start, control1-start))
				unTransformedEnd = centeredEnd
			} else {
				//now find a transformation matrix that rotates that point to y = 0 x >= 0
				let endMagnitude:SGFloat = sqrt(centeredEnd.x*centeredEnd.x + centeredEnd.y*centeredEnd.y)
				let normalizedCenteredEnd:Point = centeredEnd / endMagnitude
				let unRotating:Transform2D = Transform2D(a: normalizedCenteredEnd.x, b: normalizedCenteredEnd.y, c: -normalizedCenteredEnd.y, d: normalizedCenteredEnd.x, dx: 0.0, dy: 0.0)
				let finalTransform:Transform2D = Transform2D(translateX: -start.x, y: -start.y).concatenate(with: unRotating)
				unTransformedEnd = finalTransform.transform(end)
				transformedSegment = PathSegment(end: unTransformedEnd, shape: .cubic(finalTransform.transform(control0), finalTransform.transform(control1)))
			}
		}
		
		//find the extrema
		let extremaFractions = transformedSegment.nonTerminalExtrema(from: .zero)
		//the bug is here: we don't want the position, we want the
		let extrema:[(SGFloat, Point)] = [(0.0, Point(x: 0.0, y: 0.0))] + extremaFractions.map({ ($0, transformedSegment.position(from: .zero, fraction: $0)) })
		//if x is < 0 or > unTransformedEnd.x, we must include those regardless of y value
		let xExtrema:[(SGFloat, SGFloat)] = extrema.compactMap({
			if $0.1.x < 0 {
				return ($0.0, -$0.1.x)
			}
			if $0.1.x > unTransformedEnd.x {
				return ($0.0, $0.1.x - unTransformedEnd.x)
			}
			return nil
		})
		
		//now for all y extrema
		let allY:[(SGFloat, SGFloat)] = extrema.map({ ($0.0, $0.1.y) })
		let sortedY:[(SGFloat, SGFloat)] = allY.sorted(by:{ $0.1 < $1.1 })
		//take the lowest & highest, and then take their absolute values
		let finalY:[(SGFloat, SGFloat)] = [sortedY.first, sortedY.last].compactMap({ $0 }).map({ ($0.0, abs($0.1)) })
		//sort from smallest fraction to largest fraction
		var allMaxima:[(SGFloat, SGFloat)] = (xExtrema + finalY).sorted(by:{ $0.0 < $1.0 }).filter({ $0.0 > 0.0 && $0.0 < 1.0 })
		//remove duplicates, which is easy, because they are all sorted now
		var i:Int = 0
		while i+1 < allMaxima.count {
			if allMaxima[i].0 == allMaxima[i+1].0 {
				//remove the one with the smaller maxima
				if allMaxima[i].1 > allMaxima[i+1].1 {
					allMaxima.remove(at: i)
				} else {
					allMaxima.remove(at: i+1)
				}
				continue
			}
			i += 1
		}
		return allMaxima
	}
	
	//returns an array of PathSegments suitably subdivided until none has maxDeviationsFromLinearity > linearity
	public func subDivided(from start:Point, linearity:SGFloat)->[PathSegment] {
		var accumulatedSegments:[PathSegment] = []	//stack
		var segmentsToDivide:[PathSegment] = [self]	//FILO, push on top, pop off top
		var preceedingEndPoint:Point = start
		while segmentsToDivide.count > 0 {
			let segment:PathSegment = segmentsToDivide.removeLast()
			let fractions:[(fraction:SGFloat, distance:SGFloat)] = segment.maxDeviationsFromLinearity(from: preceedingEndPoint)
			let divisionSpots:[(fraction:SGFloat, distance:SGFloat)] = fractions.filter({ $0.distance > linearity })
			
			if divisionSpots.count == 0 {
				accumulatedSegments.append(segment)
				preceedingEndPoint = segment.end
				continue
			}
			
			//easy slow algorithm: only split at the first extrema, will re-encounter the other later
			let (firstSegment, secondSegment) = segment.subDivide(at: divisionSpots[0].fraction, start: preceedingEndPoint)
			segmentsToDivide.append(secondSegment)
			segmentsToDivide.append(firstSegment)
			
			/*
			//TODO: hard fast algorithm: go ahead and split at all the points so we don't bother re-doing this math again
			let sortedDivisionSpots:[(fraction:SGFloat, distance:SGFloat)] = divisionSpots
			var previousFraction:SGFloat = 0.0
			var replacementSegments:[PathSegment] = []
			//not finished
*/
		}
		return accumulatedSegments
	}
	
	public func position(from start:Point, fraction:SGFloat)->Point {
		switch shape {
		case .line:
			let line:Line = Line(point0: start, point1: end)
			return line.pointAtFraction(fraction)
			
		case .quadratic(let control):
			let controlLine0:Line = Line(point0: start, point1: control)
			let controlLine1:Line = Line(point0: control, point1: end)
			let halfStart:Point = controlLine0.pointAtFraction(fraction)
			let halfEnd:Point = controlLine1.pointAtFraction(fraction)
			let halfLine:Line = Line(point0: halfStart, point1: halfEnd)
			let point:Point = halfLine.pointAtFraction(fraction)
			return point
			
		case .cubic(let control0, let control1):
			let (cx3, cx2, cx1, cx0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.x, P1: control0.x, P2: control1.x, P3: end.x)
			let (cy3, cy2, cy1, cy0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.y, P1: control0.y, P2: control1.y, P3: end.y)
			let polynomialX:SGFloat = pow(fraction, 3)*cx3 + pow(fraction, 2)*cx2 + fraction*cx1 + cx0
			let polynomialY:SGFloat = pow(fraction, 3)*cy3 + pow(fraction, 2)*cy2 + fraction*cy1 + cy0
			return Point(x: polynomialX, y: polynomialY)
		}
	}
	
	///returns the point on the segment at the given percentage, and also the direction in which the line is traveling
	///the direction will not be normalized, and may not be non-zero
	public func postionAndDerivative(from start:Point, fraction:SGFloat)->(Point, Point) {
		switch shape {
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
			let deriv = finalBar.point1 - finalBar.point0
			//haven't figured out how to get new control points from the polynomials
		/*	let (cx3, cx2, cx1, cx0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.x, P1: control0.x, P2: control1.x, P3: end.x)
			let (cy3, cy2, cy1, cy0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.y, P1: control0.y, P2: control1.y, P3: end.y)
			let polynomialX:SGFloat = pow(fraction, 3)*cx3 + pow(fraction, 2)*cx2 + fraction*cx1 + cx0
			let polynomialY:SGFloat = pow(fraction, 3)*cy3 + pow(fraction, 2)*cy2 + fraction*cy1 + cy0
			print(polynomialX - point.x)
			print(polynomialY - point.y)
			let polynomialDx = 3*pow(fraction, 2)*cx3 + 2*fraction*cx2 + cx1
			let polynomialDy = 3*pow(fraction, 2)*cy3 + 2*fraction*cy2 + cy1	*/
//			print(deriv.crossProductMagnitude(rhs: Point(x: polynomialDx, y: polynomialDy)))
			return (point, deriv)
		}
	}
	
	/// De Casteljau subdivision for bezier curves
	///this segment can be replaced by the two segments in the result
	public func subDivide(at fraction:SGFloat, start:Point)->(PathSegment, PathSegment) {
		switch shape {
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
	
	///if the segment is quadratic or cubic, this replaces it with a line
	public func replacingWithLines(from start:Point)->PathSegment {
		switch shape {
		case .line:
			return self
		default:
			return PathSegment(end: end, shape: .line)
		}
	}
	
	
	///assumes all segments are lines, not curves
	public func isPoint(_ point:Point, within distance:SGFloat, start:Point, cap:Path.LineCap = .round, join:Path.LineJoin = .round)->Bool {
		switch shape {
		case .line:
			if point.y - distance > max(start.y, end.y) {
				return false
			}
			if point.x + distance < min(start.x, end.x) {
				return false
			}
			if point.x - distance > max(start.x, end.x) {
				return false
			}
			if point.y + distance < min(start.y, end.y) {
				return false
			}
			
			let line:Line = Line(point0: start, point1: end)
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
				return false
			}
			return Line(point0: nearest, point1: point).length <= distance
			
		case .quadratic(let control):
			let startXMinusPointX:SGFloat = start.x - point.x
			let startYMinusPointY:SGFloat = start.y - point.y
//			let d0:SGFloat = startXMinusPointX * startXMinusPointX + startYMinusPointY * startYMinusPointY
			let d1:SGFloat = (control.x - start.x) * startXMinusPointX + (control.y - start.y) * startYMinusPointY
			let d2:SGFloat = (start.x - 2 * control.x + end.x) * startXMinusPointX + (start.y - 2 * control.y + end.y) * startYMinusPointY + 2 * (control.x - start.x) * (control.x - start.x) + 2 * (control.y - start.y) * (control.y - start.y)
			let d3:SGFloat = (start.x - 2 * control.x + end.x) * (control.x - start.x) + (start.y - 2 * control.y + end.y) * (control.y - start.y)
			let d4:SGFloat = (start.x - 2 * control.x + end.x) * (start.x - 2 * control.x + end.x) + (start.y - 2 * control.y + end.y) * (start.y - 2 * control.y + end.y)
			//solutions are the fractions of the closest points, whereever those are
			let solutions = realCubeRoots(a: d4, b: 3 * d3, c: d2, d: d1)
			let acceptibleSolutions = solutions.filter({ 0.0 <= $0 && $0 <= 1.0 })
			var solvedPoints:[Point] = acceptibleSolutions.map({ position(from: start, fraction: $0) })
			solvedPoints.append(contentsOf:[start, end])	//with round cap style, this works, for butt, we need explicit handling of the derviative
			let closeEnoughPoints:[Point] = solvedPoints.filter { Line(point0: $0, point1: point).length <= distance }
			return closeEnoughPoints.count > 0
			
		case .cubic(let control0, let control1):
			return PathSegment(end: end, shape: .line).isPoint(point, within: distance, start: start, cap: cap, join: join)
			//for now, if you'd like smooth cubic bezier strokes, subdivide the path using .subDivided(linearity:
		}
	}
	
	
	///assuming a ray which extends from point to Point(x:-∞, y:point.y), how many intercepts with this path segment are there?
	func intersectionCountFromNegativeInfinityX(at point:Point, from start:Point, overlapping:Path.SubPathOverlapping)->Int {
		switch shape {
		case .line:
			if point.y > start.y && point.y > end.y {
				return 0
			}
			if point.y < start.y && point.y < end.y {
				return 0
			}
			if point.x < start.x && point.x < end.x {
				return 0
			}
			var yIntercepts:Int = 0
			//to avoid double-counting a vertex as being on both sides, an endpoint is considered a hit only if both vertexes are on the same y side of the infinity x line, in this case >=
		/*	if start.y == point.y, start.x <= point.x, end.y >= point.y {
				yIntercepts += 1
			}
			if end.y == point.y, end.x <= point.x, start.y >= point.y {
				yIntercepts += 1
			}
			if yIntercepts > 0 {
				return yIntercepts
			}*/
			let minX:SGFloat = min(start.x, end.x)
			let falseLine = Line(point0:Point(x: minX - 1.0, y: point.y), point1: point)
			let intersection:(Point, SGFloat)? = Line(point0: start, point1: end).intersectionWithLine(falseLine)
			if let intersectionX = intersection?.0.x, intersectionX > point.x {
				return 0
			}
			return intersection == nil ? 0 : 1
			
		case .quadratic(let control):
			let minX = min(start.x, control.x, end.x)
			if point.x < minX {
				return 0
			}
			let minY = min(start.y, control.y, end.y)
			if point.y < minY {
				return 0
			}
			let maxY = max(start.y, control.y, end.y)
			if point.y > maxY {
				return 0
			}
			let falseLine = Line(point0: Point(x: minX - 1.0, y: point.y), point1: point)
			let intersectionPoints = intersections(with: falseLine, start: start)
			if let onlyIntersection = intersectionPoints.first
				,intersectionPoints.count == 1 {
				//logic to avoid double counting start/end nodes
			/*	if start.y < point.y, end.y <= point.y {
					return 0
				}
				if start.y <= point.y, end.y < point.y {
					return 0
				}*/
			}
			return intersectionPoints.count
			
		case .cubic(let control0, let control1):
			let minX = min(start.x, control0.x, control1.x, end.x)
			if point.x < minX {
				return 0
			}
			let minY = min(start.y, control0.y, control1.y, end.y)
			if point.y < minY {
				return 0
			}
			let maxY = max(start.y, control0.y, control1.y, end.y)
			if point.y > maxY {
				return 0
			}
			let falseLine = Line(point0:Point(x: minX - 1.0, y: point.y), point1: point)
			let intersectionPoints = intersections(with: falseLine, start: start)
			if let onlyIntersection = intersectionPoints.first, intersectionPoints.count == 1 {
				//TODO: add logic to avoid double counting start/end nodes
				//no idea if this is actually right
			/*	if start.y < point.y, end.y <= point.y {
					return 0
				}
				if start.y <= point.y, end.y < point.y {
					return 0
				}*/
			}
			return intersectionPoints.count
		}
	}
	
	
	func intersections(with line:Line, start:Point)->[(Point, SGFloat)] {
		switch shape {
		case .line:
			guard let (point, fraction):(Point, SGFloat) = Line(point0: start, point1: end).intersectionWithLine(line) else {
				return []
			}
			if fraction < 0.0 || fraction > 1.0 {
				return []
			}
			return [(point, fraction)]
		
		case .quadratic(let control0):
			
			let O:Point = line.point1
			let lineDiff:Point = O-line.point0
			let D:Point = lineDiff/lineDiff.magnitude
			
			let alpha:SGFloat = (start + end - 2 * control0).crossProductMagnitude(rhs: D)
			let beta:SGFloat = (2 * (control0 - start)).crossProductMagnitude(rhs: D)
			let gamma:SGFloat = (start-O).crossProductMagnitude(rhs: D)
			let roots:[SGFloat] = realQuadraticRoots(a: alpha, b: beta, c: gamma)
			let acceptibleRoots:[SGFloat] = roots.filter({ 0 <= $0 || $0 <= 1.0 })
			
			let solutionsPositions:[(Point, SGFloat)] = acceptibleRoots.map {
				return (position(from: start, fraction: $0), $0)
			}
			let inRangePositions:[(Point, SGFloat)] = solutionsPositions.filter { pointAndFraction in
				guard let fraction = line.intersection(with: pointAndFraction.0) else { return false }
				return fraction >= 0.0 && fraction <= 1.0
			}
			let sortedInRangePositions = inRangePositions.sorted(by: {$0.1 < $1.1})
			return sortedInRangePositions
			
			
		case .cubic(let control0, let control1):
			//up to 3 solutions
			let A:SGFloat = line.point1.y - line.point0.y
			let B:SGFloat = line.point0.x - line.point1.x
			let C:SGFloat = line.point0.x*(line.point0.y-line.point1.y) + line.point0.y*(line.point1.x-line.point0.x)
			
			let (xa, xb, xc, xd) = bezierCoefficients(P0: start.x, P1: control0.x, P2: control1.x, P3: end.x)
			let (ya, yb, yc, yd) = bezierCoefficients(P0: start.y, P1: control0.y, P2: control1.y, P3: end.y)
			
			let solutions = realCubeRoots(a: A*xa + B*ya
				, b: A*xb + B*yb
				, c: A*xc + B*yc
				, d: A*xd + B*yd + C)
			
			//constrain results to 0..<1
			let acceptibleSolutions = solutions.filter({ 0.0 <= $0 && $0 <= 1.0 })
			
			func position(t:SGFloat)->Point {
				return Point(x:xa*t*t*t + xb*t*t + xc*t + xd
					, y: ya*t*t*t + yb*t*t + yc*t + yd)
			}
			let solutionsCoordinates:[(Point, SGFloat)] = acceptibleSolutions.map({
				return (self.position(from: start, fraction: $0), $0)
			})
			let inRangePositions:[(Point, SGFloat)] = solutionsCoordinates.filter { pointAndFraction in
				guard let fraction = line.intersection(with: pointAndFraction.0, tolerance: 0.02) else { return false }
				return fraction >= 0.0 && fraction <= 1.0
			}
			return inRangePositions.sorted(by: {$0.1 < $1.1})
		}
	}
	
}

///turns control point coordinates in one dimension into coefficients of a cubic polynomial
func bezierCoefficients(P0:SGFloat,P1:SGFloat,P2:SGFloat,P3:SGFloat)->(SGFloat, SGFloat,SGFloat, SGFloat) {
	return (
		-P0 + 3.0 * P1 + -3.0 * P2 + P3,
		3.0 * P0 - 6.0 * P1 + 3.0 * P2,
		-3.0*P0 + 3.0 * P1,
		P0
	)
}




