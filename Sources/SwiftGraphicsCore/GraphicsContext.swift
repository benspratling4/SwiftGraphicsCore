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
	
	/// fills if fillShader is non-nil
	/// strokes if stroke is non-nil
	/// to get a solid color, use SolidColorShader as the Shader
	/// Shader colors should already be in the color space of the context
	func drawPath(_ path:Path, fillShader:Shader?, stroke:(Shader, StrokeOptions)?)
	
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


public struct StrokeOptions {
	public var cap:Path.LineCap
	public var join:Path.LineJoin
	public var lineWidth:SGFloat
	
	public init(lineWidth:SGFloat, cap:Path.LineCap = .round, join:Path.LineJoin = .round) {
		self.lineWidth = lineWidth
		self.cap = cap
		self.join = join
	}
}


public struct GraphicsContextState {
	
	///init with the existing current transformation
	public init(transformation:Transform2D = .identity) {
		self.transformation = transformation
	}
	
	///when rendered, a point will appear to be at let apparentCoordiantes:Point = transform.transform(providedCoordinates)
	///unlike other properties which can be set sparsely, the transformation is always the complete concatenation of all lower transformations
	public var transformation:Transform2D = .identity
	//TODO: clipping masks....
	
}

public protocol ResolvedGraphicsContextState : class {
	var transformation:Transform2D { get }
	func applyTransformation(_ transformation:Transform2D)
	//TODO: clipping masks....
	
}
