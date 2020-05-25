//
//  Font.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 11/8/17.
//

import Foundation


/*
Font Manifesto:
Fonts will be represented abstractly, but all abstract fonts will resolve options to produce a RenderingFont which produces glyph indexes for a piece of text, and offsets of those glyphs.
then produces a Path for each glyph.
For contexts like an SVG context, the paths are not really needed, the specs of the font are enough
for a .pdf context, the font itself could get embedded in the document, optionally.
For a sampled graphics contexts, the context will create a subsampled representation of the glyph and cache it based on all the font properties, including size., thus.  the subsample cache will over subsample the path shape by squaring the resolution.  For instance, if the subsample resolution is 3, (making a 3x3 grid of subsampled points), the glyph cache will do a 9x9 subsample cache of single bits of which points are in or out of the shape.  It will be reused for all matching translation, rotation and skew transforms, or scale transforms within 1 + 1/resolution^2.  When drawing text, the cache of each glyph, once created, will be used to determine which regular subsampled points to fill with color, and then blend accordingly.
By using an over-subsampled cache, expensive curve flattening & complicated path testing is replaced by mere point transformations.  BY over- subsampling the charcters, we still achieve our desired antialiasing


*/


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
	
	func rendering(options:[FontOptionValue])->RenderingFont?
}


///this is a place where you can cache renderings of a font at a given size, or precompute some cvt values
public protocol RenderingFont {
	var font:Font { get }
	
	var optionValues:[FontOptionValue] { get }
	
	///assumes unicode encoding, not Windows specs or MacRoman
	func gylphIndexes(text:String)->[Int]
	
	///primitive calculations for layout
	func glyphAdvances(indices:[Int])->[SGFloat]
	
	func path(glyphIndex:Int)->Path
	
	//not sure if we will add this here
//	func render(text:String, context:SampledGraphicsContext, at point:Point)
		
}


///caches a particular font
class SampledFontCache {
	
	//key is glyph index
	var cache:[Int:(SampledImage, Point)] = [:]
	
	
	//TODO: write me
	
	
}
