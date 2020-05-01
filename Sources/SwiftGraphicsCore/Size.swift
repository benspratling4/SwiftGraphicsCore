//
//  Size.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 10/28/17.
//

import Foundation


public struct Size : Hashable {
	//Instance variables
	public var width:SGFloat
	public var height:SGFloat
	public init(width:SGFloat, height:SGFloat) {
		self.width = width
		self.height = height
	}
	
	//computable properties
	
	public var area:SGFloat {
		return width * height
	}
	
	//Common Constants
	public static let zero:Size = Size(width: 0.0, height: 0.0)
	
	//Self & Float math
	
	public static func /(lhs:Size, rhs:SGFloat)->Size {
		return Size(width: lhs.width/rhs, height: lhs.height/rhs)
	}
	
	public static func *(lhs:SGFloat, rhs:Size)->Size {
		return Size(width: lhs * rhs.width, height: lhs * rhs.height)
	}
	
	// Self & Self Math
	
	public static func +(lhs:Size, rhs:Size)->Size {
		return Size(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
	}
	
	public static func -(lhs:Size, rhs:Size)->Size {
		return Size(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
	}
	
	public static prefix func -(lhs:Size)->Size {
		return Size(width: -lhs.width, height: -lhs.height)
	}
	
	
	//Hashable
	
	public func hash(into hasher: inout Hasher) {
		width.hash(into: &hasher)
		height.hash(into: &hasher)
	}
	
	
	//Equatable
	
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.width == rhs.width && lhs.height == rhs.height
	}
	
	
	//TODO: define math operations, including arithmetic with point
	
}
