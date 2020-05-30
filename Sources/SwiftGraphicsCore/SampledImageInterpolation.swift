//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/29/20.
//

import Foundation


///generic protocol, which interpolates one image into another

public protocol SampledImageInterpolation {
	
	init(_ image:SampledImage, into destination:SampledImage, in rect:Rect, transform:Transform2D)throws
	
	func perform()
	
//	func colorFor(x:Int, y:Int)->SampledColor?
}


public enum NearestNeighborInterpolationError:Error {
	case invalidDimensions
}

public struct NearestNeighborInterpolation : SampledImageInterpolation {
	
	
	public init(_ image:SampledImage, into destination:SampledImage, in rect:Rect, transform:Transform2D)throws {
		originalImageSize = image.size
		self.image = image
		self.destination = destination
		self.rect = rect
		self.transform = transform
		guard rect.size.width > 0, rect.size.height > 0 else { throw NearestNeighborInterpolationError.invalidDimensions }	//transform will not be invertible
		guard let supporter:InterpolationSupport = InterpolationSupport(originalImageSize: originalImageSize, destinationBufferSize: destination.size, rect: rect, transform: transform) else { throw NearestNeighborInterpolationError.invalidDimensions }
		self.support = supporter
	}
	
	var image:SampledImage
	var destination:SampledImage
	var rect:Rect
	var transform:Transform2D
	var support:InterpolationSupport
	var originalImageSize:Size
	
	//we need to use this just to prove the testing algorithms work
	public func perform() {

		//now scan all the pixels in the scanable ImageRect
		let pixelXMin = max(0, Int(support.scanRegion.origin.x.rounded()))
		let pixelYMin = max(0, Int(support.scanRegion.origin.y.rounded()))
		let pixelXMax = min(destination.dimensions.width-1, Int(support.scanRegion.maxX.rounded()))
		let pixelYMax = min(destination.dimensions.height-1, Int(support.scanRegion.maxY.rounded()))
		
		//for each pixel, if it's in the original image, find it's coordinates, and use the pixel value nearest the original
		for pixelX in pixelXMin...pixelXMax {
			for pixelY in pixelYMin...pixelYMax {
				let point:Point = Point(x: SGFloat(pixelX) + 0.5, y: SGFloat(pixelY) + 0.5)
				guard support.isPointInOriginalImage(point) else { continue }
				let transformedCoords:Point = support.inverseTransform.transform(point)
				//now get the coords of the nearest pixel
				let originalX:Int = Int(transformedCoords.x.rounded(.down))
				let originalY:Int = Int(transformedCoords.y.rounded(.down))
				
				guard originalX >= 0, originalX < image.dimensions.width, originalY >= 0, originalY < image.dimensions.width else { continue }
				
				let originalImageColor:SampledColor = image[originalX, originalY]
				let destinationColor:SampledColor = destination[pixelX, pixelY]
				destination[pixelX, pixelY] = destination.colorSpace.composite(source:[(originalImageColor, antialiasFactor:1.0)]
					,over: destinationColor)
			}
		}
	}
}


///given an image and a destination buffer size, and a destination image rect and a transform, provides the scan region coordinates,
///testing for whether a given scan region point is in the image destination
///and can transform that point back to the original image coordinates
public struct InterpolationSupport {
	
	public var scanRegion:Rect
	
	public init?(originalImageSize:Size, destinationBufferSize:Size, rect:Rect, transform:Transform2D) {
		//convert the destination rect into a transform
		let scaleTransform:Transform2D = Transform2D(scaleX: rect.size.width/originalImageSize.width, scaleY: rect.size.height/originalImageSize.height)
		let translationTransform:Transform2D = Transform2D(translateX: rect.origin.x, y: rect.origin.y)
		let totalTransform:Transform2D = transform.concatenate(with: scaleTransform).concatenate(with: translationTransform)
		//the inverse of the transform converts pixel coordinates into original image-space coordinates
		inverseTransform = totalTransform.inverted
		
		//how do we know if a pixel is in the space of the interpolation?
		
		//break the image rect into two triangles, transform the triangles, a point is in the original image rect, if it is in the triangles
		let originalImageXmaxYMin:Point = Point(x: originalImageSize.width, y: 0)
		let originalImageXminYMax:Point = Point(x: 0, y: originalImageSize.height)
		let imageTriangle0:Triangle = Triangle(point0: Point(x: 0, y: 0), point1: originalImageXmaxYMin, point2: originalImageXminYMax)
		let imageTriangle1:Triangle = Triangle(point0: Point(x: originalImageSize.width, y: originalImageSize.height), point1: originalImageXmaxYMin, point2: originalImageXminYMax)
		
		transformedTriangle0 = totalTransform.transform(imageTriangle0)
		transformedTriangle1 = totalTransform.transform(imageTriangle1)
		
		let imageRectBoundingBox:Rect = transformedTriangle0.boundingBox.unioning(transformedTriangle1.boundingBox)
		guard let scanableImageRect:Rect = imageRectBoundingBox.roundedOut.intersection(with:Rect(origin: .zero, size: destinationBufferSize) ) else { return nil }
		
		scanRegion = scanableImageRect
	}
	
	public var inverseTransform:Transform2D
	
	public func isPointInOriginalImage(_ point:Point)->Bool {
		return transformedTriangle0.contains(point) || transformedTriangle1.contains(point)
	}
	
	private let transformedTriangle0:Triangle
	private let transformedTriangle1:Triangle
	
}
