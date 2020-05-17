//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/16/20.
//

import Foundation


fileprivate struct Borders : OptionSet, CaseIterable {
	var rawValue: UInt8
	static let xMinus = Borders(rawValue: 1<<0)
	static let xPlus = Borders(rawValue: 1<<1)
	static let yMinus = Borders(rawValue: 1<<2)
	static let yPlus = Borders(rawValue: 1<<3)
	static var allCases:[Borders] {
		return [.xMinus, .xPlus, .yMinus, .yPlus]
	}
	//show all the borders, except the ones in border
	static func withoutOpposite(of border:Borders)->Borders {
		var borders:Borders = Borders(Borders.allCases)
		if border.contains(.xMinus){
			borders.remove(.xPlus)
		}
		if border.contains(.xPlus){
			borders.remove(.xMinus)
		}
		if border.contains(.yMinus){
			borders.remove(.yPlus)
		}
		if border.contains(.yPlus){
			borders.remove(.yMinus)
		}
		return borders
	}
}

///the line we use to test for intersections for a given point
fileprivate func intersectionTestLine(for point:Point, inverseSubDivision:SGFloat)->Line {
	let xMax:SGFloat = point.x + inverseSubDivision
	return Line(point0: Point(x: point.x, y: point.y), point1: Point(x: xMax, y: point.y))
}


//xminus, xplus, yminus, yplus
fileprivate func borderLines(for point:Point, with borders:Borders, inverseSubDivision:SGFloat)->[(Line, Borders)] {
	let minX:SGFloat = point.x
	let maxX:SGFloat = point.x + inverseSubDivision
	let minY:SGFloat = point.y - inverseSubDivision/2.0
	let maxY:SGFloat = minY + inverseSubDivision
	return [
		borders.contains(.xMinus) ? (Line(point0: Point(x: minX, y: minY), point1: Point(x: minX, y: maxY)), .xMinus) : nil,
		borders.contains(.xPlus) ? (Line(point0: Point(x: maxX, y: minY), point1: Point(x: maxX, y: maxY)), .xPlus) : nil,
		borders.contains(.yMinus) ? (Line(point0: Point(x: minX, y: minY), point1: Point(x: maxX, y: minY)), .yMinus) : nil,
		borders.contains(.yPlus) ? (Line(point0: Point(x: minX, y: maxY), point1: Point(x: maxX, y: maxY)), .yPlus) : nil,
	].compactMap({ $0 })
}

extension Line {
	///line must be in pixel coordinates
	///the handler block is called once for each sub pixel the line intersects
	func iterateIntersectedSubPixelCoordinates(subdivision:Int, within frame:Rect, _ handler:(_ x:Int, _ y:Int)->()) {
		let inverseSubDivision:SGFloat = 1.0/SGFloat(subdivision)
		let halfInverseSubDivision:SGFloat = inverseSubDivision/2.0
		let maxXCoord:Int = Int(frame.size.width) * subdivision - 1
		let maxYCoord:Int = Int(frame.size.height) * subdivision - 1
		func subPixelCoordinateToPoint(x:Int, y:Int)->Point {
			return Point(x:frame.origin.x + SGFloat(x/subdivision) +  inverseSubDivision*SGFloat(x%subdivision)
				,y:frame.origin.y + SGFloat(y/subdivision) + halfInverseSubDivision + inverseSubDivision*SGFloat(y%subdivision))
		}
		
		func coordsFor(_ point:Point, rounding:FloatingPointRoundingRule)->(Int, Int) {
			let xDiff:SGFloat = point.x - frame.origin.x
			let xFloor:Int = Int((xDiff).rounded(rounding)) //doing crazy math to make sure pixel coordinates remain stable over large pixel counts
			let xExtra:Int = Int(((xDiff - SGFloat(xFloor)) / inverseSubDivision).rounded(rounding))
			let yDiff:SGFloat = point.y - frame.origin.y
			let yFloor:Int = Int((yDiff).rounded(rounding)) //doing crazy math to make sure pixel coordinates remain stable over large pixel counts
			let yExtra:Int = Int(((yDiff - SGFloat(yFloor)) / inverseSubDivision).rounded(rounding))
			return ( xFloor*subdivision + xExtra, yFloor*subdivision + yExtra )
		}
		
		var coords:(Int, Int) = (0,0)	//we shouldn't have to define it, but the compiler can't figure out the proof that we will define it later
		var preceedingBorder:Borders = Borders([])	////the border previously crossed
		if frame.contains(point0) {
			coords = coordsFor(point0, rounding:.down)
		} else if frame.contains(point1) {
			coords = coordsFor(point1, rounding:.down)
		} else {
			//detect glancing blow
			//this is quite common
			while true {
				//find one side of the rect the line intersects, start with that intersection point
				let xMin = Line(point0: Point(x: frame.origin.x, y: frame.origin.y), point1: Point(x: frame.origin.x, y: frame.maxY))
				if let intersection:Point = xMin.segmentIntersection(with:self) {
					coords = coordsFor(intersection, rounding: .up)
					preceedingBorder = [.xPlus]
					break
				}
				
				let xMax = Line(point0: Point(x: frame.maxX, y: frame.origin.y), point1: Point(x: frame.maxX, y: frame.maxY))
				if let intersection:Point = xMax.segmentIntersection(with:self) {
					coords = coordsFor(intersection, rounding: .down)
					preceedingBorder = [.xMinus]
					break
				}
				
				let yMin = Line(point0: Point(x: frame.origin.x, y: frame.origin.y), point1: Point(x: frame.maxX, y: frame.origin.y))
				if let intersection:Point = yMin.segmentIntersection(with:self) {
					coords = coordsFor(intersection, rounding: .up)
					preceedingBorder = [.yMinus]
					break
				}
				
				let yMax = Line(point0: Point(x: frame.origin.x, y: frame.maxY), point1: Point(x: frame.maxX, y: frame.maxY))
				if let intersection:Point = yMax.segmentIntersection(with:self) {
					coords = coordsFor(intersection, rounding: .down)
					preceedingBorder = [.yPlus]
					break
				}
				//we were unable to find a starting point, return
				return
			}
		}
		
		while true {
			//prevent handler from being called for invalid coordinates
			if coords.0 < 0{
				return
			}
			if coords.1 < 0{
				return
			}
			if coords.0 > maxXCoord {
				return
			}
			if coords.1 > maxYCoord {
				return
			}
			//determine if the line intersect's this subpixel's crossing line
			let subPixelCenter:Point = subPixelCoordinateToPoint(x: coords.0, y: coords.1)
			let lineToCross:Line = intersectionTestLine(for:subPixelCenter, inverseSubDivision:inverseSubDivision)
			if let fraction:SGFloat = lineToCross.fractionOfSegmentIntersection(with: self), fraction < 1.0 {
				handler(coords.0, coords.1)
			}
			//find the side it leaves from
			//TODO: make sure these lines intersects on their actual segments, and not beyond
			let allBorderLines:[(Line, Borders)] = borderLines(for:subPixelCenter, with:.withoutOpposite(of:preceedingBorder), inverseSubDivision:inverseSubDivision)
			var leavingSides:[Borders] = allBorderLines.filter({ $0.0.segmentIntersection(with: self) != nil }).map({ $0.1 })
			if point0.x == point1.x, point0.x == lineToCross.point0.x {
				//we're a vertical line at the xmin of this cell
				//pretend we didn't intersect the xmin line
				leavingSides = leavingSides.filter({ $0 != .xMinus })
			}
			if leavingSides.isEmpty {
				//the line did not leave, we're done
				return
			}
			
			//what about horizontal or vertical lines?
			
			//determine the next point to go to
			if leavingSides.contains(.xPlus) {
				coords.0 += 1
			}
			if leavingSides.contains(.xMinus) {
				coords.0 -= 1
			}
			if leavingSides.contains(.yPlus) {
				coords.1 += 1
			}
			if leavingSides.contains(.yMinus) {
				coords.1 -= 1
			}
			preceedingBorder = Borders(leavingSides)
			//loop
		}
	}
}
