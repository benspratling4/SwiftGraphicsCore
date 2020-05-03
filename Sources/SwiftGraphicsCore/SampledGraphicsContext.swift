//
//  SampledGraphicsContext.swift
//  SwiftGraphics
//
//  Created by Ben Spratling on 11/3/17.
//

import Foundation


public class SampledGraphicsContext : GraphicsContext {
	
	///initializes new storage for the context
	public init(dimensions:Size, colorSpace:ColorSpace) {
		underlyingImage = SampledImage(width: Int(dimensions.width.rounded()), height: Int(dimensions.height.rounded()), colorSpace: colorSpace, bytes: nil)
		updateSubSampledPixels()
	}
	
	///uses the data already found in the image
	public init(imageBuffer:SampledImage) {
		self.underlyingImage = imageBuffer
		updateSubSampledPixels()
	}
	
	public enum Antialiasing {
		
		public enum SubSampleResolution : Int {
			case one = 1	//equivalent to no antialiasing
			case three = 3
			case five = 5
		}
		
		///subsampling is accomplished by sub-dividing each pixel into x equal-width areas in each direction
		case subsampling(resolution:SubSampleResolution)
		
		///pixels and shapes are divided into triangles, whose overlapping percentages are calculated precisely
//		case triangulation
		
		//TODO: sub-pixel rendering, taking into account the layout of colored pixels...
	}
	
	
	public var antialiasing:Antialiasing = .subsampling(resolution:.one) {
		didSet {
			updateSubSampledPixels()
		}
	}
	
	private func updateSubSampledPixels() {
		guard case .subsampling(resolution:let resolution) = antialiasing else {
			subsampledPixelTemplates = [Point(x: 0.5, y: 0.5)]
			return
		}
		
		// precalculate the per-pixel offsets for subsamples
		let divisionsPerSide:SGFloat = SGFloat(resolution.rawValue)
		let increment:SGFloat = 1.0/divisionsPerSide
		let offsets:[[Point]] = (0..<Int(divisionsPerSide)).map { (dx) -> [Point] in
			return (0..<Int(divisionsPerSide)).map({ (dy) -> Point in
				return Point(x: SGFloat(dx)*increment+(increment*0.5), y: SGFloat(dy)*increment+(increment*0.5))
			})
		}
		subsampledPixelTemplates = offsets.flatMap({return $0})
	}
	
	private var subsampledPixelTemplates:[Point]?
	
	func subsampledPixelCoordinates(row:Int, column:Int)->[Point] {
		return subsampledPixelTemplates?.map({ (offset) -> Point in
			return Point(x: SGFloat(column), y: SGFloat(row)) + offset
		}) ?? [Point(x: SGFloat(column)+0.5, y: SGFloat(row)+0.5)]
	}
	
	
	private var states:[GraphicsContextState] = [GraphicsContextState()]
	
	
	///color space must match self' color space
	public func strokePath(_ path:Path, color:SampledColor, lineWidth:SGFloat) {
		//TODO: make me more efficient by following the bounding boxes of each underlying subpath segment
		guard let boundingBox:Rect = path.boundingBox else { return }
		let inverseTransform:Transform2D = currentState.transformation.inverted
		//intersect with viewable area
		var affectedRect:Rect = Rect(boundingPoints:boundingBox.corners.map {return inverseTransform.transform($0) })
		affectedRect = affectedRect.roundedOut
		guard let affectedDrawingArea = affectedRect.intersection(with: Rect(origin: .zero, size: size)) else { return }
		for row in Int(affectedDrawingArea.origin.y)..<Int(affectedDrawingArea.maxY) {
			for column in Int(affectedDrawingArea.origin.x)..<Int(affectedDrawingArea.maxX) {
				switch antialiasing {
				case .subsampling(resolution: let resolution):
					let subSampleLocations:[Point] = subsampledPixelCoordinates(row: row, column: column)
					let subSamplePixelLocation:[Point] = subSampleLocations.map({ states[states.count-1].transformation.transform($0) })
					let hitCount:Float32 = Float32(subSamplePixelLocation.filter({ path.isPoint($0, within: lineWidth) }).count)
					if hitCount <= 0.0 { continue }
					let antialiasRatio:Float32 = hitCount/Float32(subSampleLocations.count)
					if underlyingImage.colorSpace.hasAlpha {
						let underValue:SampledColor = underlyingImage[column, row]
						underlyingImage[column, row] = underlyingImage.colorSpace.composite(source:[(color, antialiasFactor:antialiasRatio)], over: underValue)
					} else {
						underlyingImage[column, row] = color
					}
//				case .triangulation:
//					//idea is to break down the pixel into two triangles, then use geometry to perfectly calculate the affected triangles
//					//TODO: write me
//					break
				}
			}
		}
	}
	
	
	/// color must already be in self's colorSpace
	public func fillPath(_ path:Path, color:SampledColor) {
		//use the bounding rects of the subpaths?
		guard let boundingBox:Rect = path.boundingBox else { return }
		let inverseTransform:Transform2D = currentState.transformation.inverted
		//intersect with viewable area
		var affectedRect:Rect = Rect(boundingPoints:boundingBox.corners.map {return inverseTransform.transform($0) })
		affectedRect = affectedRect.roundedOut
		guard let affectedDrawingArea = affectedRect.intersection(with: Rect(origin: .zero, size: size)) else { return }
		
		for row in Int(affectedDrawingArea.origin.y)..<Int(affectedDrawingArea.maxY) {
			for column in Int(affectedDrawingArea.origin.x)..<Int(affectedDrawingArea.maxX) {
				switch antialiasing {
				case .subsampling(resolution: let resolution):
					let subSampleLocations:[Point] = subsampledPixelCoordinates(row: row, column: column)
					let subSamplePixelLocation:[Point] = subSampleLocations.map({ states[states.count-1].transformation.transform($0) })
					let hitCount:Float32 = Float32(subSamplePixelLocation.filter({ path.contains($0) }).count)
					if hitCount <= 0.0 { continue }
					let antialiasRatio:Float32 = hitCount/Float32(subSampleLocations.count)
					if underlyingImage.colorSpace.hasAlpha {
						let underValue:SampledColor = underlyingImage[column, row]
						underlyingImage[column, row] = underlyingImage.colorSpace.composite(source:[(color, antialiasFactor:antialiasRatio)], over: underValue)
					} else {
						underlyingImage[column, row] = color
					}
//				case .triangulation:
//					//idea is to break down the pixel into two triangles, then use geometry to perfectly calculate the affected triangles
//					//TODO: write me
//					break
				}
			}
		}
	}
	
	
	struct PixelTriangleCoordinate : Hashable {
		var row:Int
		var column:Int
		
		var hashValue: Int {
			return row.hashValue ^ column.hashValue
		}
		static func ==(lhs:PixelTriangleCoordinate, rhs:PixelTriangleCoordinate)->Bool {
			return lhs.row == rhs.row && lhs.column == rhs.column
		}
		var firstTriangle:Triangle {
			let minX:SGFloat = SGFloat(column)
			let minY:SGFloat = SGFloat(row)
			let maxX:SGFloat = SGFloat(column+1)
			let maxY:SGFloat = SGFloat(row+1)
			return Triangle(point0: Point(x: minX, y: minY), point1: Point(x: maxX, y: minY), point2: Point(x: minX, y: maxY))
		}
		
		var secondTriangle:Triangle {
			let minX:SGFloat = SGFloat(column)
			let minY:SGFloat = SGFloat(row)
			let maxX:SGFloat = SGFloat(column+1)
			let maxY:SGFloat = SGFloat(row+1)
			return Triangle(point0: Point(x: maxX, y: minY), point1: Point(x: maxX, y: maxY), point2: Point(x: minX, y: maxY))
		}
	}
	
	public func saveState() {
		states.append(GraphicsContextState(transformation:states.last?.transformation ?? .identity))
	}
	
	public func popState() {
		states.removeLast()
	}
	
	
	public var size:Size {
		let (width, height) = underlyingImage.dimensions
		return Size(width: SGFloat(width), height: SGFloat(height))
	}
	
	fileprivate var underlyingImage:SampledImage
	
	public var colorSpace:ColorSpace {
		return underlyingImage.colorSpace
	}
	
	public var image:SampledImage {
		//copy the image
		return SampledImage(width: underlyingImage.dimensions.width, height: underlyingImage.dimensions.height, colorSpace: underlyingImage.colorSpace, bytes: underlyingImage.bytes)
	}
	
	
	public var currentState:ResolvedGraphicsContextState {
		return ProxyState(context: self)
	}
	
	private func resolveStateProperty<Value>(key:KeyPath<GraphicsContextState,Optional<Value>>)->Optional<Value> {
		for state in states.reversed() {
			if let value = state[keyPath:key] {
				return value
			}
		}
		return nil
	}
	
	class ProxyState : ResolvedGraphicsContextState {
		var transformation: Transform2D {
			get {
				guard let stateCount:Int = context?.states.count, stateCount > 0 else { return .identity }
				return context?.states[stateCount-1].transformation ?? .identity
			}
		}
		
		func applyTransformation(_ transformation:Transform2D) {
			guard let context = self.context, context.states.count > 0 else { return }
			let oldTransformation = context.states[context.states.count-1].transformation
			let newTransformation = oldTransformation.concatenate(with: transformation)
			context.states[context.states.count-1].transformation = newTransformation
		}
		
		init(context:SampledGraphicsContext) {
			self.context = context
		}
		
		private weak var context:SampledGraphicsContext?
		
	}
	
	
	public func drawImage(_ image:SampledImage, in rect:Rect) {
		//TODO: write me!!!
		//calculate the transform of the image, concatenate for a temp transform
		//locate the pixels affected by the rect
		
		//transform them into the image space with the temp transform
		
		//invert the current transform to get
		let inverseTransform:Transform2D = currentState.transformation.inverted
		//intersect with viewable area
		var affectedRect:Rect = Rect(boundingPoints:rect.corners.map {return inverseTransform.transform($0) })
		affectedRect = affectedRect.roundedOut
		guard let affectedDrawingArea = affectedRect.intersection(with: Rect(origin: .zero, size: size)) else { return }
		
		for row in Int(affectedDrawingArea.origin.y)..<Int(affectedDrawingArea.maxY) {
			for column in Int(affectedDrawingArea.origin.x)..<Int(affectedDrawingArea.maxX) {
				//TODO: write me
				/*
				guard let alias = antialiasing else {
					//use nearest neighbor
					let halfPixel:Point = Point(x: 0.5, y: 0.5)
					let pixel:Point = Point(x: SGFloat(column), y: SGFloat(row)) + halfPixel
					var transformed:Point = states[states.count-1].transformation.transform( pixel)
					transformed = transformed - halfPixel
					let xCoord:Int = Int(transformed.x.rounded())
					let yCoord:Int = Int(transformed.y.rounded())
					if xCoord < 0 || yCoord < 0 || xCoord >= image.dimensions.width || yCoord >= image.dimensions.height {
						continue
					}
					let sample:SampledColor = image[xCoord, yCoord]
					if underlyingImage.colorSpace.hasAlpha {
						let underValue:SampledColor = underlyingImage[column, row]
								underlyingImage[column, row] = underlyingImage.colorSpace.composite(source:[(sample, antialiasFactor: 1.0)], over: underValue)
					} else {
								underlyingImage[column, row] = sample
					}
					continue
				}
				
				switch alias {
				case .subsampling(resolution: let resolution):
					//TODO: write me
					let subSampleLocations:[Point] = subsampledPixelCoordinates(row: row, column: column)
					var antiliasingFraction:Float32 = 1.0/Float32(subSampleLocations.count)
					let pixel:Point = Point(x: SGFloat(column), y: SGFloat(row))
					for subPixel in subSampleLocations {
						let transformed:Point = states[states.count-1].transformation.transform(pixel + subPixel)
						
						let xCoord:Int = Int(transformed.x.rounded())
						let yCoord:Int = Int(transformed.y.rounded())
						if xCoord < 0 || yCoord < 0 || xCoord >= image.dimensions.width || yCoord >= image.dimensions.height {
							continue
						}
						let sample:SampledColor = image[xCoord, yCoord]
						if underlyingImage.colorSpace.hasAlpha {
							let underValue:SampledColor = underlyingImage[column, row]
							underlyingImage[column, row] = underlyingImage.colorSpace.composite(source: [(sample, antialiasFactor:antiliasingFraction)], over: underValue)
						} else {
							underlyingImage[column, row] = sample
						}
						continue
					}
					
					
					
					
				case .triangulation:
					
					//TODO: write me
					
					
					continue
					
				}
				*/
				
				
				
			}
		}
		
	}
	
	
	
}
