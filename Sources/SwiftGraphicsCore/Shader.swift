//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/14/20.
//

import Foundation



public protocol Shader {
	
	func color(at point:Point)->SampledColor
	
}


public struct SolidColorShader : Shader {
	
	public var color:SampledColor
	
	public init(color:SampledColor) {
		self.color = color
	}
	
	//Shader
	public func color(at point:Point)->SampledColor {
		return color
	}
	
}
