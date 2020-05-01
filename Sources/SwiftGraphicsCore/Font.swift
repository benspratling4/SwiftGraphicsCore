//
//  Font.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 11/8/17.
//

import Foundation

public protocol FontOption {
	var name:String { get }
	var minValue:Float32? { get }	//if nil, there is no lower limit
	var maxValue:Float32? { get }	//if nil, there is no upper limit
	var increment:Float32? { get }	//if nil, the value is continuous
	func value(_ value:Float32)->FontOptionValue
	
}


extension String {

	///to be used for the size option
	public static let FontOptionNameSize:String = "size"
}


public protocol FontOptionValue {
	var option:FontOption { get }
}


///this is an abstract collection of general font information, which can be rendered at many sizes with many options
public protocol Font {
	var name:String { get }
	
	var options:[FontOption] { get }	//like size, lineweight, etc...
	
	func rendering(options:[FontOptionValue])->RenderingFont
}


///this is a place where you can cache renderings of a font at a given size, or precompute some cvt values
public protocol RenderingFont {
	var font:Font { get }
	
	var optionValues:[FontOptionValue] { get }
	
	///primitive calcualtions for layout
	func glyphAdvances(text:String)->[SGFloat]
	
	///
	func paths(text:String)->[Path]

	//not sure if we will add this here
//	func render(text:String, context:SampledGraphicsContext, at point:Point)
		
}

