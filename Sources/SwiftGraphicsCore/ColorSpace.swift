//
//  SGColorSpace.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 10/28/17.
//

import Foundation

/// a color space gives meaning to color sample components
/// by converting them into other color spaces
/// and performs math operations
public protocol ColorSpace {
	
	func toAbstractRGB(_:SampledColor)->Color
	
	func fromAbstractRGB(_:Color)->SampledColor
	
	var bytesPerComponent:Int { get }
	
	var componentCount:Int { get }
	
	///alpha channel is always the last channel
	var hasAlpha:Bool { get }
	
	var black:SampledColor { get }
	
	var white:SampledColor { get }
	
	var clear:SampledColor { get }
	
	// math functions
	/// antialiasFactor must be 0.0...1.0
	func composite(source:[(SampledColor, antialiasFactor:Float32)], over:SampledColor)->SampledColor
	
}
