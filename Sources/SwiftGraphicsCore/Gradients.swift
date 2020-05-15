//
//  Gradients.swift
//  
//
//  Created by Ben Spratling on 5/13/20.
//

import Foundation


public struct GradientColorStop {
	public init(position:SGFloat, color:SampledColor) {
		self.position = position
		self.color = color
	}
	
	///0.0 is at start, 1.0 is at end
	public var position:SGFloat
	public var color:SampledColor
}


public struct GradientContinuation : OptionSet {
	public var rawValue: UInt8
	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}
	
	public static let continuesBefore:GradientContinuation = GradientContinuation(rawValue: 1<<0)
	public static let continuesAfter:GradientContinuation = GradientContinuation(rawValue: 1<<1)
}


public struct LinearGradient : Shader {
	public var start:Point
	public var end:Point
	public var stops:[GradientColorStop]
	public var continuation:GradientContinuation
	
	public init(start:Point, end:Point, stops:[GradientColorStop], continuation:GradientContinuation) {
		self.start = start
		self.end = end
		self.stops = stops.sorted(by: { $0.position < $1.position})
		self.continuation = continuation
	}
	
	public func color(at point:Point)->SampledColor {
		let line = Line(point0: start, point1: end)
		let (_, position) = line.nearestPoint(to: point)
		return stops.resolvedColor(position: position, continuation: continuation)
	}
}


public struct RadialGradient : Shader {
	public var startCenter:Point
	public var endCenter:Point
	public var startRadius:SGFloat
	public var endRadius:SGFloat
	public var stops:[GradientColorStop]
	
	///before is a radius smaller than start, after is radius larger than end
	public var continuation:GradientContinuation
	
	public init(startCenter:Point, startRadius:SGFloat, endCenter:Point,  endRadius:SGFloat, stops:[GradientColorStop], continuation:GradientContinuation) {
		self.startCenter = startCenter
		self.endCenter = endCenter
		self.startRadius = startRadius
		self.endRadius = endRadius
		self.stops = stops.sorted(by: { $0.position < $1.position})
		self.continuation = continuation
	}
	
	public func color(at point:Point)->SampledColor {
		//Does not handle before or after
		//we need to know f, (how far between start center and end center)
		let d = endRadius
		let p = point.x
		let s = startCenter.x
		let e = endCenter.x
		let r = point.y
		let t = startCenter.y
		let g = endCenter.y
		let q = startRadius
		
		var solutions:[SGFloat] = []
		let denominator0:SGFloat = d*d - 2 * d * q - e*e + 2 * e * s - g*g + 2 * g * t + q*q - s*s - t*t
		if denominator0 != 0.0 {
			let termA = (2 * d * q + 2 * e * p - 2 * e * s + 2 * g * r - 2 * g * t - 2 * p * s - 2 * q*q - 2 * r * t + 2 * s*s + 2 * t*t)
			let f = (-sqrt(termA * termA - 4 * (-(p*p) + 2 * p * s + q*q - r*r + 2 * r * t - s*s - t*t) * (d*d - 2 * d * q - e*e + 2 * e * s - g*g + 2 * g * t + q*q - s*s - t*t)) + 2 * ( -d * q - e * p + e * s - g * r + g * t + p * s + q*q + r * t - s*s - t*t) ) / (2 * denominator0)
			solutions.append(f)
		}
		
		if denominator0 != 0.0 {
			let termB = (2 * d * q + 2 * e * p - 2 * e * s + 2 * g * r - 2 * g * t - 2 * p * s - 2 * q*q - 2 * r * t + 2 * s*s + 2 * t*t)
			let f = (sqrt(termB*termB - 4 * (-(p*p) + 2 * p * s + q*q - r*r + 2 * r * t - s*s - t*t) * (d*d - 2 * d * q - e*e + 2 * e * s - g*g + 2 * g * t + q*q - s*s - t*t)) + 2 * (-d * q - e * p + e * s - g * r + g * t + p * s + q*q + r * t - s*s - t*t) )/(2 * denominator0)
			solutions.append(f)
		}
		
		//take the largest solution
		guard let position = solutions
			.filter({(0.0...1.0).contains($0)})
			.sorted()
			.last
			else {
			//return clear? for now
			//TODO: adjust the color space to the ones in the stops
			return SampledColor(components: [[0],[0],[0],[0]])
		}
		return stops.resolvedColor(position: position, continuation:[])
	}
}


extension Array where Element == GradientColorStop {
	
	public func resolvedColor(position:SGFloat, continuation:GradientContinuation)->SampledColor {
		guard (0.0...1.0).contains(position) else {
			if position < 0.0
				,continuation.contains(.continuesBefore)
				,let firstColor:SampledColor = first?.color
			{
				return firstColor
			}
			else if position > 1.0
				,continuation.contains(.continuesAfter)
				,let lastColor:SampledColor = last?.color
			{
				return lastColor
			}
			return SampledColor(components: [[0],[0],[0],[0]])
		}
		let preceedingStop:GradientColorStop? = reversed().first(where:{ $0.position <= position })
		let succeedingStop:GradientColorStop? = first(where:{ $0.position >= position })
		if let firstStop:GradientColorStop = preceedingStop
			,let lastStop:GradientColorStop = succeedingStop {
			let stopDiff:SGFloat = lastStop.position - firstStop.position
			let fractionStartColor = stopDiff == 0.0 ? 0.0 : 1.0 - (position - firstStop.position) / stopDiff
			let fractionEndColor = stopDiff == 0.0 ? 1.0 : 1.0 - (lastStop.position - position) / stopDiff
			
			let r:UInt8 = UInt8(clamping: Int((SGFloat(firstStop.color.components[0][0]) * fractionStartColor + SGFloat(lastStop.color.components[0][0]) * fractionEndColor).rounded()))
			let g:UInt8 = UInt8(clamping: Int((SGFloat(firstStop.color.components[1][0]) * fractionStartColor + SGFloat(lastStop.color.components[1][0]) * fractionEndColor).rounded()))
			let b:UInt8 = UInt8(clamping: Int((SGFloat(firstStop.color.components[2][0]) * fractionStartColor + SGFloat(lastStop.color.components[2][0]) * fractionEndColor).rounded()))
			let a:UInt8 = UInt8(clamping: Int((SGFloat(firstStop.color.components.last?[0] ?? 255) * fractionStartColor + SGFloat(lastStop.color.components.last?[0] ?? 255) * fractionEndColor).rounded()))
			
			return SampledColor(components: [[r],[g],[b],[a]])
		} else if let eitherStop = preceedingStop ?? succeedingStop {
			return eitherStop.color
		}
		
		//failover, return clear
		//TODO: adjust the color space to the ones in the stops
		return SampledColor(components: [[0],[0],[0],[0]])
	}
	
}
