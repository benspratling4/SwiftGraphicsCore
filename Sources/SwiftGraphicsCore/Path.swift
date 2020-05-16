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
		
		///if a point is inside any subpath, it is "in".  This makes multiple subpaths always additive
		case nonZero
		
		//case windingNumber // not currently supported
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
			let hitCount:Int = subPaths.filter({ $0.contains(point) }).count
			return hitCount % 2 != 0
		case .nonZero:
			return subPaths.map({$0.contains(point)}).reduce(false, { $0 || $1 })
		}
	}
	
	public func isPoint(_ point:Point, within distance:SGFloat, cap:LineCap = .round, join:LineJoin = .round)->Bool {
		return subPaths.map({ $0.isPoint(point, within:distance, cap: cap, join:join) }).reduce(false, { $0 || $1 })
	}
	
	public mutating func move(to point:Point) {
		subPaths.append(SubPath(startingPoint: point))
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
	
	public func byCLosing()->Path {
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
		guard subPaths.count >= 0 else { return nil }
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
}



///Simple Bezier Path
public struct SubPath {
	public var segments:[PathSegment] = []
	
	internal init(segments:[PathSegment]) {
		self.segments = segments
	}
	
	//public var closed:Bool = false
	public init(startingPoint:Point) {
		segments = [.init(end: startingPoint, shape: .point)]
	//	closed = false
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
		guard let startPoint = segments.first?.end else { return }
		addLine(to: startPoint)
	}
	
	public init(inRect:Rect) {
		segments = [.init(end: inRect.origin, shape: .point)
			,.init(end: inRect.origin + Point(x: inRect.size.width, y: 0.0), shape: .line)
			,.init(end: inRect.origin + Point(x: inRect.size.width, y: inRect.size.height), shape: .line)
			,.init(end: inRect.origin + Point(x: 0.0, y: inRect.size.height), shape: .line)
			,.init(end: inRect.origin, shape: .line)
		]
	}
	
	///does not assume path is closed
	public func isPoint(_ point:Point, within distance:SGFloat, cap:Path.LineCap = .round, join:Path.LineJoin = .round)->Bool {
		if segments.count == 0 {
			return false
		}
		if segments.count == 1 {
			return Line(point0: segments[0].end, point1: point).length <= distance
		}
		var lastEnd:Point = segments[0].end
		for i in 1..<segments.count {
			let segment:PathSegment = segments[i]
			let newEnd:Point = segment.end
			defer {
				lastEnd = newEnd
			}
			//check if it's within the distance from a bounding box
			let fastBoudingRect:Rect = segment.fastBoundingBox(from:lastEnd)
			if !fastBoudingRect.outset(uniform:Size(width: distance, height: distance)).contains(point) {
				return false
			}
			//and a narrower bouding box
//			let boudingRect:Rect = segment.boundingBox(from:lastEnd)
//			if boudingRect.outset(uniform:Size(width: distance, height: distance)).contains(point) {
				if segment.isPoint(point, within: distance, start: lastEnd, cap: cap, join:join) {
					return true
				}
//			}
		}
		return false
	}
	
	///tight fit
	public var boundingBox:Rect {
		if segments.count < 1 {
			return Rect(origin: .zero, size: .zero)
		}
		var bounds:Rect = Rect(origin: segments[0].end, size: .zero)
		var previousEnd:Point = segments[0].end
		for segment in segments {
			bounds.union(segment.boundingBox(from: previousEnd))
			previousEnd = segment.end
		}
		return bounds
	}
	
	///loose fit, includes control points
	public var fastBoundingBox:Rect {
		if segments.count < 1 {
			return Rect(origin: .zero, size: .zero)
		}
		var bounds:Rect = Rect(origin: segments[0].end, size: .zero)
		var previousEnd:Point = segments[0].end
		for segment in segments {
			bounds.union(segment.fastBoundingBox(from: previousEnd))
			previousEnd = segment.end
		}
		return bounds
	}
	
	
	public func subDivided(linearity:SGFloat)->SubPath {
		var newSegments:[PathSegment] = []
		var previousEnd:Point = .zero
		for segment in segments {
			newSegments.append(contentsOf: segment.subDivided(from:previousEnd, linearity: linearity))
			previousEnd = segment.end
		}
		return SubPath(segments:newSegments)
	}
	
	
	public func replacingWithLines()->SubPath {
		var newSegments:[PathSegment] = []
		var previousEnd:Point = .zero
		for segment in segments {
			newSegments.append(segment.replacingWithLines(from: previousEnd))
			previousEnd = segment.end
		}
		return SubPath(segments:newSegments)
	}
	
	///		///precise calculation, imprecise exclusion provided by the overestimatedConvexHull
	/// currently assumes the edges are all lines...  oh well.
	///have not tested subpaths
	public func contains(_ point:Point)->Bool {
		if segments.count < 2 {
			return false
		}
		var previousStart:Point = segments[0].end
		var runningCount:Int = 0
		for segmentIndex in 1..<segments.count {
			let segment = segments[segmentIndex]
			runningCount += segment.intersectionCountFromNegativeInfinityX(at: point, from: previousStart)
			previousStart = segment.end
		}
		return runningCount % 2 != 0
	}
	
	//TODO: write me supports being able to split curves
//	func intersection(rect:Rect)->SubPath? {
//
//	}
	
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
	
	
	public func boundingBox(from start:Point)->Rect {
		var points:[Point]
		switch shape {
		case .point:
			points = [end]
			
		default:
			points = [start, end]
		}
		points.append(contentsOf: nonTerminalExtrema(from: start).map({ position(from: start, fraction: $0) }))
		return Rect(boundingPoints: points)
	}
	
	
	public func fastBoundingBox(from start:Point)->Rect {
		switch shape {
		case .point:
			return Rect(origin: end, size: .zero)
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
		case .point:
			return []	//never any non-terminal extrema
			
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
		case .point:
			return []
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
				let unRotating:Transform2D = Transform2D(a: normalizedCenteredEnd.x, b: -normalizedCenteredEnd.y, c: normalizedCenteredEnd.y, d: normalizedCenteredEnd.x, dx: 0.0, dy: 0.0)
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
				let unRotating:Transform2D = Transform2D(a: normalizedCenteredEnd.x, b: -normalizedCenteredEnd.y, c: normalizedCenteredEnd.y, d: normalizedCenteredEnd.x, dx: 0.0, dy: 0.0)
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
		var accumulatedSegments:[PathSegment] = [self]
		var index:Int = 0
		var preceedingEndPoint:Point = start
		while index < accumulatedSegments.count {
			let segment:PathSegment = accumulatedSegments[index]
			let fractions:[(fraction:SGFloat, distance:SGFloat)] = segment.maxDeviationsFromLinearity(from: preceedingEndPoint)
			let divisionSpots:[(fraction:SGFloat, distance:SGFloat)] = fractions.filter({ $0.distance > linearity })
			if divisionSpots.count == 0 {
				preceedingEndPoint = segment.end
				index += 1
				continue
			}
			
			//easy slow algorithm: only split at the first extrema, will re-encounter the other later
			let (firstSegment, secondSegment) = segment.subDivide(at: divisionSpots[0].fraction, start: start)
			accumulatedSegments.remove(at: index)
			accumulatedSegments.insert(firstSegment, at: index)
			accumulatedSegments.insert(secondSegment, at: index+1)
			
			//TODO: hard fast algorithm: go ahead and split at all the points so we don't bother re-doing this math again
			let sortedDivisionSpots:[(fraction:SGFloat, distance:SGFloat)] = divisionSpots
			var previousFraction:SGFloat = 0.0
			var replacementSegments:[PathSegment] = []
			//not finished
		}
		return accumulatedSegments
	}
	
	public func position(from start:Point, fraction:SGFloat)->Point {
		switch shape {
		case .point:
			return end
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
			let (cx3, cx2, cx1, cx0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.x, P1: control0.x, P2: control1.x, P3: end.x)
			let (cy3, cy2, cy1, cy0):(SGFloat, SGFloat, SGFloat, SGFloat) = bezierCoefficients(P0: start.y, P1: control0.y, P2: control1.y, P3: end.y)
			let polynomialX:SGFloat = pow(fraction, 3)*cx3 + pow(fraction, 2)*cx2 + fraction*cx1 + cx0
			let polynomialY:SGFloat = pow(fraction, 3)*cy3 + pow(fraction, 2)*cy2 + fraction*cy1 + cy0
			print(polynomialX - point.x)
			print(polynomialY - point.y)
			let deriv = finalBar.point1 - finalBar.point0
			let polynomialDx = 3*pow(fraction, 2)*cx3 + 2*fraction*cx2 + cx1
			let polynomialDy = 3*pow(fraction, 2)*cy3 + 2*fraction*cy2 + cy1
//			print(deriv.crossProductMagnitude(rhs: Point(x: polynomialDx, y: polynomialDy)))
			return (point, deriv)
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
	
	///if the segment is quadratic or cubic, this replaces it with a line
	public func replacingWithLines(from start:Point)->PathSegment {
		switch shape {
		case .point, .line:
			return self
		default:
			return PathSegment(end: end, shape: .line)
		}
	}
	
	
	///assumes all segments are lines, not curves
	public func isPoint(_ point:Point, within distance:SGFloat, start:Point, cap:Path.LineCap = .round, join:Path.LineJoin = .round)->Bool {
		switch shape {
		case .point:
			return Line(point0: point, point1: end).length <= distance
		case .line:
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
			//TODO: provide an exact algorthm to make curves smooth
			//naïve algorithm is to subdivide into 8 smaller cubic segments, treat them as lines
			let subT:[SGFloat] = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
			let points:[Point] = subT.map({ position(from:start, fraction:$0) })
			for i in 0..<points.count - 1 {
				let line = Line(point0: points[i], point1: points[i+1])
				if Line(point0: line.point0, point1: point).length <= distance {	//round join/cap style
					return true
				}
				if Line(point0: line.point1, point1: point).length <= distance {	//round join/cap style
					return true
				}
				let (foundPoint, fraction) = line.nearestPoint(to: point)
				if !(0.0...1.0).contains(fraction) {
					continue
				}
				if Line(point0: point, point1: foundPoint).length <= distance {
					return true
				}
			}
			return false
		}
	}
	
	
	///assuming a ray which extends from point to Point(x:-∞, y:point.y), how many intercepts with this path segment are there?
	func intersectionCountFromNegativeInfinityX(at point:Point, from start:Point)->Int {
		switch shape {
		case .point:
			return 0
			
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
		case .point:
			if let fraction = line.intersection(with: end) {
				return [(end, fraction)]
			}
			return []
			
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




