//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/16/20.
//

import Foundation


extension Line {
	
	///this method is allowed to call sub pixel coords for points for x < frame.origin.x, but not other extrema
	func simplifiedIterateIntersectedSubPixelCoordinates(subdivision:Int, within frame:Rect
		,fillMethod:Path.SubPathOverlapping = .evenOdd
		,_ handler:(_ x:Int, _ y:Int, _ crossings:Int)->()) {
		
		//check for lines lying entirely out of bounds
		if max(point0.y, point1.y) > frame.maxY {
			return
		}
		if min(point0.y, point1.y) < frame.origin.y {
			return
		}
		if min(point0.x, point1.x) > frame.maxX {
			return
		}
		//we can't reject x < origin.x, because our scan conversion algorithms need to know about all x crossings to negative infinity
		
		//check for a horizontal line
  		if point1.y == point0.y {
			//horizontal lines don't contribute to scan algorithms
			return
		}
		
		let oneOverSubdivision:SGFloat = 1.0/SGFloat(subdivision)
		let subdivisions = [Int](0..<subdivision).map({ SGFloat($0) * oneOverSubdivision })
		
		enum Axis { case x, y }
		
		func subPixelCoord(at coord:SGFloat, on axis:Axis)->Int {
			let base:SGFloat = axis == .x ? frame.origin.x : frame.origin.y
			let overBase:SGFloat = coord - base
			let down:SGFloat = overBase.rounded(.down)
			let extra:SGFloat = overBase - down
			return Int(down) * subdivision + Int((extra/oneOverSubdivision).rounded(.down))
		}
		
		//may be outside the frame
		func subPixelCoords(at point:Point)->(x:Int, y:Int) {
			return (
				subPixelCoord(at: point.x, on: .x),
				subPixelCoord(at: point.y, on: .y)
			)
		}
		
		///x or y, does not do bounds checking with frame
		func iterateSubPixelCoords(from minimum:SGFloat, to maximum:SGFloat, along axis:Axis, _ work:(Int, SGFloat)->()) {
			//start out
			let firstPixel:SGFloat = minimum.rounded(.down)
			let lastPixel:SGFloat = maximum.rounded(.down)
			//first pixel, check both bounds
			let baseCoord:Int = subPixelCoord(at:firstPixel, on:axis)
			for (sI, sub) in subdivisions.enumerated() {
				let coord:SGFloat = firstPixel + sub
				if coord >= minimum, coord <= maximum {
					work(baseCoord + sI, coord)
				}
			}
			if lastPixel == firstPixel { return }
			var pixel:SGFloat = firstPixel + 1.0
			var subPixelCoordBase:Int = baseCoord + subdivision
			while pixel < lastPixel {
				for (sI, sub) in subdivisions.enumerated() {
					let coord:SGFloat = pixel + sub
					work(subPixelCoordBase + sI,coord)
				}
				subPixelCoordBase += subdivision
				pixel += 1.0
			}
			//last pixel
			for (sI, sub) in subdivisions.enumerated() {
				let coord:SGFloat = pixel + sub
				if coord <= maximum {
					work(subPixelCoordBase + sI,coord)
				}
			}
		}
		
		///check for vertical line
		if point1.x == point0.x {
			let direction:Int
			switch fillMethod {
			case .evenOdd, .nonZero:
				direction = 1
			case .windingNumber:
				direction = point1.y - point0.y > 0 ? 1 : -1	//may be backwards
			}
			
			let xCoord:Int = subPixelCoord(at: point1.x, on: .x)
			let bottom:SGFloat = max(frame.origin.y, min(point0.y, point1.y))
			let top:SGFloat = min(frame.maxY, max(point0.y, point1.y))
			
			iterateSubPixelCoords(from: bottom, to: top, along: .y) { (subPixelYCoord, yValue) in
				handler(xCoord, subPixelYCoord, direction)
			}
			return
		}
		let direction:Int
		switch fillMethod {
		case .evenOdd, .nonZero:
			direction = 1
		case .windingNumber:
			direction = point1.y > point0.y ? 1 : -1
		}
		let bottom:SGFloat = max(frame.origin.y, min(point0.y, point1.y))
		let top:SGFloat = min(frame.maxY, max(point0.y, point1.y))
		
		iterateSubPixelCoords(from: bottom, to: top, along: .y) { (subPixelYCoord, yValue) in
			
			guard let (fraction, point) = intersectionAtYEquals(yValue) else { return }
			guard point.x < frame.maxX else { return }
			if fillMethod == .windingNumber {
				if yValue == top { return }
			}
			else {
				if yValue == top { return }	//is this right?
				//TODO: for evenOdd, only count intersections if the other point is below a particular side
//				if yValue == point1.y, point0.y < yValue { return }
			}
			let xCoord = subPixelCoord(at: point.x, on: .x)
			handler(xCoord, subPixelYCoord, direction)
		}
	}
	
	
	func intersectionAtXEquals(_ x:SGFloat)->(SGFloat, Point)? {
		if x < min(point0.x, point1.x) {
			return nil
		}
		if x > max(point0.x, point1.x) {
			return nil
		}
		let denominator:SGFloat = point1.x - point0.x
		if denominator == 0 {
			return (0.0, point0)
		}
		let fraction = (x - point0.x)/denominator
		return (fraction, pointAtFraction(fraction))
	}
	
	func intersectionAtYEquals(_ y:SGFloat)->(SGFloat, Point)? {
		if y < min(point0.y, point1.y) {
			return nil
		}
		if y > max(point0.y, point1.y) {
			return nil
		}
		let denominator:SGFloat = point1.y - point0.y
		if denominator == 0 {
			return (0.0, point0)
		}
		let fraction = (y - point0.y)/denominator
		return (fraction, pointAtFraction(fraction))
	}
	
}
