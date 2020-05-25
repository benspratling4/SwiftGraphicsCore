//
//  GenericRGBAColorSpace.swift
//  SwiftSampledImage
//
//  Created by Ben Spratling on 11/5/17.
//

import Foundation

///8-bit rgb/rgba color space
public struct GenericRGBAColorSpace : ColorSpace {
	
	public init(hasAlpha:Bool) {
		self.hasAlpha = hasAlpha
	}
	
	public func toAbstractRGB(_ input:SampledColor)->Color {
		func toScaled(value:UInt8)->Float32 {
			return Float32(value)/255.0
		}
		return Color(components: input.components.map({return toScaled(value: $0)}))
	}
	
	public func fromAbstractRGB(_ input:Color)->SampledColor {
		func scaled(value:Float32)->UInt8 {
			var value = value
			value = min(value, 1.0)
			value = max(value, 0.0)
			return UInt8((value * 255.0).rounded())
		}
		return SampledColor(components: input.components.map({return scaled(value: $0)}))
	}
	
	public var bytesPerComponent:Int { return 1 }
	
	public var componentCount:Int { return  hasAlpha ? 4: 3 }
	
	
	///alpha channel is always the last channel
	public var hasAlpha:Bool
	
	public var black:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[0, 0, 0, 255]
				: [0, 0, 0]
		)
	}
	
	public var white:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[255, 255, 255, 255]
				: [255, 255, 255]
		)
	}
	
	public var gray:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[128, 128, 128, 255]
				: [128, 128, 128]
		)
	}
	
	public var red:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[255, 0, 0, 255]
				: [255, 0, 0]
		)
	}
	
	public var green:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[0, 255, 0, 255]
				: [0, 255, 0]
		)
	}
	
	public var blue:SampledColor {
		return SampledColor(components:
			hasAlpha ?
				[0, 0, 255, 255]
				: [0, 0, 255]
		)
	}
	
	///black with 0% opacity, when hasalpha == false, just black
	public var clear:SampledColor {
		return SampledColor(components:
			hasAlpha ? [0, 0, 0, 0]
				: [0, 0, 0]
		)
	}
	
	///multiplies two byte-sized values, as if the 0...255 values were floats from 0.0...1.0
	private func byteMultiply(_ a:UInt8, _ b:UInt8)->UInt8 {
		var product:UInt16 = UInt16(a) * UInt16(b)
		product /= 255
		return UInt8(product & 0x00FF)	//the mask shouldn't be necessary, right...?
	}
	
	public func composite(source:[(SampledColor, antialiasFactor:Float32)], over:SampledColor)->SampledColor {
		//linear sum of anti-alias'd values
		let sourceRed:UInt8 = source.reduce(0) { (value:UInt8, aSource:(SampledColor, antialiasFactor:Float32)) -> UInt8 in
			//TODO: handle near misses of addition overflow
			return UInt8((Float32(aSource.0.components[0]) * aSource.antialiasFactor).rounded()) + value
		}
		let sourceGreen:UInt8 = source.reduce(0) { (value, aSource) -> UInt8 in
			//TODO: handle near misses of addition overflow
			return UInt8((Float32(aSource.0.components[1]) * aSource.antialiasFactor).rounded()) + value
		}
		let sourceBlue:UInt8 = source.reduce(0) { (value, aSource) -> UInt8 in
			//TODO: handle near misses of addition overflow
			return UInt8((Float32(aSource.0.components[2]) * aSource.antialiasFactor).rounded()) + value
		}
		if !hasAlpha {
			return SampledColor(components: [sourceRed, sourceGreen, sourceBlue])
		}
		
		let sourceAlpha:UInt8 = source.reduce(0) { (value, aSource) -> UInt8 in
			let scaled:UInt8 = UInt8((Float32(aSource.0.components[3]) * aSource.antialiasFactor).rounded())
			if 255-value < scaled {
				return 255
			}
			return scaled + value
		}
		let sourceRedPreMultiplied:UInt8 = sourceRed// byteMultiply(sourceRed, sourceAlpha)
		let sourceGreenPreMultiplied:UInt8 = sourceGreen//byteMultiply(sourceGreen, sourceAlpha)
		let sourceBluePreMultiplied:UInt8 = sourceBlue//byteMultiply(sourceBlue, sourceAlpha)
		
		let alphaFilter:UInt8 = 255 - sourceAlpha
		let oldAlpha:UInt8 = over.components[3]
		let alphaProduct:UInt8 = byteMultiply(alphaFilter, oldAlpha)
		let overRedPreMultiplied:UInt8 = byteMultiply(over.components[0], alphaProduct)
		let overGreenPreMultiplied:UInt8 = byteMultiply(over.components[1], alphaProduct)
		let overBluePreMultiplied:UInt8 = byteMultiply(over.components[2], alphaProduct)
		
		let newRed:UInt8 = sourceRedPreMultiplied + overRedPreMultiplied
		let newGreen:UInt8 = sourceGreenPreMultiplied + overGreenPreMultiplied
		let newBlue:UInt8 = sourceBluePreMultiplied + overBluePreMultiplied
		
		let newAlpha:UInt8 = sourceAlpha + alphaProduct
		
		return SampledColor(components: [newRed, newGreen, newBlue, newAlpha])
	}
}

