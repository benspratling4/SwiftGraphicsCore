//
//  GraphicsContext.swift
//  SwiftGeometry2D
//
//  Created by Ben Spratling on 10/31/17.
//

import Foundation

public protocol GraphicsContext : class {
	
	var size:Size { get }
	
	var colorSpace:ColorSpace { get }
	
	///color should already be in the color space of the context
	func strokePath(_ path:Path, color:SampledColor, lineWidth:SGFloat)
	
	///color should already be in the color space of the context
	func fillPath(_ path:Path, color:SampledColor)
	
	///in a SampledGraphicsContext, the colorspaces must match
	func drawImage(_ image:SampledImage, in rect:Rect)
	
	///also set properties on this directly
	///this object is often a proxy.  it may not be defined to keep it
	var currentState:ResolvedGraphicsContextState { get }
	
	/// adds a new graphics state to the stack
	func saveState()
	
	///removes the current state from the stack
	///your drawing code should pop once for each time it saves
	func popState()
	
}



public struct GraphicsContextState {
	
	///init with the existing current transformation
	public init(transformation:Transform2D = .identity) {
		self.transformation = transformation
	}
	
	///unlike other properties which can be set sparsely, the transformation is always the complete concatenation of all lower transformations
	public var transformation:Transform2D = .identity
	//TODO: clipping masks....
	
}

public protocol ResolvedGraphicsContextState : class {
	var transformation:Transform2D { get }
	func applyTransformation(_ transformation:Transform2D)
	//TODO: clipping masks....
	
}
