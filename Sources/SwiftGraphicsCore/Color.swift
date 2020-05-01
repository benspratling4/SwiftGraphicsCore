//
//  SGColor.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 10/28/17.
//

import Foundation

///Basic abstraction of color
public struct Color {
	///color components are always in the abstract RGBA color space
	public var components:[Float32]
	public init(components:[Float32]) {
		self.components = components
	}
	
	public static let white:Color = Color(components: [1, 1, 1, 1])
	
	public static let black:Color = Color(components: [0, 0, 0, 1])
	
	public static let clear:Color = Color(components: [0, 0, 0, 0])
	
}


///Practical color
///assumes a color space
public struct SampledColor {
	public var components:[[UInt8]]
	public init(components:[[UInt8]]) {
		self.components = components
	}
}
