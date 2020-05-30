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
	
	//well, that's useless...
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
	
	public func drawPath(_ path:Path,  fill:FillOptions?, stroke:StrokeOptions?) {
		let currentTransform:Transform2D = currentState.transformation
		let inverseTransform:Transform2D = currentTransform.inverted
		let pathInPixelCoordiantes:Path = currentTransform.transform(path)
		
		switch antialiasing {
		case .subsampling(resolution: let resolution):
			
			let subsampleHeight:SGFloat = 1.0/SGFloat(resolution.rawValue)
			let subsampleOffset:SGFloat = subsampleHeight/2.0
			let subdividedPathInPixelCoordiantes:Path = pathInPixelCoordiantes
				.subDivided(linearity: 0.5/SGFloat(resolution.rawValue))
				.explicitlyClosingAllSubpaths()	//adds a line for the implicitly closed side of the path, allowing our line-based algorithms to efficiently compute interior angles
				.replacingWithLines()
				
			//improve me by rendering as in a pixel buffer, and then compositing over the original image
			if let fillOptions = fill
				,let boundingBox:Rect = subdividedPathInPixelCoordiantes.boundingBox?.roundedOut
				,let affectedDrawingArea = boundingBox.intersection(with: Rect(origin: .zero, size: size)) {	//use the bounding rects of the subpaths?
				let shader:Shader = fillOptions.shader
				
				//intersect with viewable area
				let rows:[Int] = (Int(affectedDrawingArea.origin.y)..<Int(affectedDrawingArea.maxY)).map({ $0 })
				let subSampleIndexes:[SGFloat] = (0..<resolution.rawValue).map({ $0 }).map({ SGFloat($0) })
				let subsampledYCoordinatesByPixel:[[SGFloat]] = rows.map({ (y)->[SGFloat] in
					return subSampleIndexes.map({ subSampleI in
						return SGFloat(y) + subsampleOffset + (subSampleI * subsampleHeight)
					})
				})
				let subsampledYCoordinates:[SGFloat] = subsampledYCoordinatesByPixel.flatMap({$0})
				
				//go ahead and compute all the x values, too
				let columns:[Int] = (Int(affectedDrawingArea.origin.x)..<Int(affectedDrawingArea.maxX)).map({ $0 })
				let subsampledXCoordinatesByPixel:[[SGFloat]] = columns.map({ (x)->[SGFloat] in
					return subSampleIndexes.map({ subSampleI in
						return SGFloat(x) + subsampleOffset + (subSampleI * subsampleHeight)
					})
				})
				let subsampledXCoordinates:[SGFloat] = subsampledXCoordinatesByPixel.flatMap({$0})
				
				//make a giant grid of Int's, one for each subpixel
				//then for each line segment, iterateIntersectedSubPixelCoordinates(subdivision:..., incrementing the subpixel for which it falls into
				//then for each horizontal line, scan across leaving the sum of all preceeding counts, starting with
				let subPixelWidth:Int = subsampledXCoordinates.count
				//FIXME: since all we need to know if whether it's even or odd, we can use a single bit for each subpixel
				var allSubPixelCrossings:[Int] = [Int](repeating: 0, count: subsampledXCoordinates.count * subsampledYCoordinates.count)
				//increment the counts in allSubPixelCrossings for each line's crossing
				for subPath in subdividedPathInPixelCoordiantes.subPaths {
					var previousCoord:Point = subPath.start
					for segment in subPath.segments {
						let line = Line(point0: previousCoord, point1: segment.end)
						line.simplifiedIterateIntersectedSubPixelCoordinates(subdivision: resolution.rawValue, within: affectedDrawingArea, fillMethod:fillOptions.subPathOverlapping) { (subPixelX, subPixelY, crossings) in
							let actualX:Int = max(0, subPixelX)
							if actualX >= subPixelWidth {
//								print("untimely exit X")
								return }
							if subPixelY < 0 || subPixelY >= subsampledYCoordinates.count {
//								print("untimely exit Y")
								return }
							allSubPixelCrossings[subPixelY * subPixelWidth + actualX] += crossings
						}
						previousCoord = segment.end
					}
				}
				
				//now replace each entry of the sum of all the ones before it
				for row in 0..<subsampledYCoordinates.count {
					var previousSum:Int = 0
					for column in 0..<subPixelWidth {
						let newSum:Int = previousSum + allSubPixelCrossings[row * subPixelWidth + column]
						allSubPixelCrossings[row * subPixelWidth + column] = newSum
						previousSum = newSum
					}
				}
				
				//TODO: now every cell with an even number does not have the fill, and every one with an odd number has the fill
				//for each pixel, get the counts of each sub pixel,
				let antialiasDilutionRatio:Float = 1.0/Float(resolution.rawValue*resolution.rawValue)
				for (rowIndex, row) in rows.enumerated() {
					for (columnIndex, column) in columns.enumerated() {
						//access each subpixel
						var hitColors:[SampledColor]  = []
						for subPixelx in 0..<resolution.rawValue {
							for subPixelY in 0..<resolution.rawValue {
								let subPixelCoordX = columnIndex*resolution.rawValue + subPixelx
								let subPixelCoordY = rowIndex*resolution.rawValue + subPixelY
								let crossingCount:Int = allSubPixelCrossings[subPixelCoordY * subPixelWidth + subPixelCoordX]
								if fillOptions.subPathOverlapping.contains(intersectionCount: crossingCount) {
									let coordinate = Point(x: subsampledXCoordinates[subPixelCoordX], y: subsampledYCoordinates[subPixelCoordY])
									hitColors.append(shader.color(at: coordinate))	//20% of time is on this line
								}
							}
						}
						
						if hitColors.count == 0 { continue }
						let allColors:[(SampledColor, antialiasFactor:Float32)] = hitColors.map({ ($0, antialiasDilutionRatio) })	//15% of time here
						let underValue:SampledColor = underlyingImage[column, row]
						underlyingImage[column, row] = underlyingImage.colorSpace.composite(source:allColors, over: underValue)	//10% of time here
					}
				}
			}
			
			//Stroking
			if let strokeOptions = stroke {
				//TODO: make me more efficient by generating outlines of the stroke and then filling that outline path with non-zero fill.
				let crudeStrokingPath = pathInPixelCoordiantes.subDivided(linearity: 0.5).replacingWithLines()
				if let boundingBox:Rect = crudeStrokingPath.boundingBox {
					let shader = strokeOptions.shader
					
					//TODO: make me more efficient by following the bounding boxes of each underlying subpath segment
					//intersect with viewable area
					let halfLineWidth:SGFloat = strokeOptions.lineWidth/2
				
					var affectedRect:Rect = Rect(boundingPoints:boundingBox.corners.map { return currentTransform.transform($0) })
					affectedRect = affectedRect.outset(uniform: Size(width: strokeOptions.lineWidth, height:halfLineWidth))
					affectedRect = affectedRect.roundedOut
					if let affectedDrawingArea = affectedRect.intersection(with: Rect(origin: .zero, size: size)) {
						for row in Int(affectedDrawingArea.origin.y)..<Int(affectedDrawingArea.maxY) {
							for column in Int(affectedDrawingArea.origin.x)..<Int(affectedDrawingArea.maxX) {
								let subSampleLocations:[Point] = subsampledPixelCoordinates(row: row, column: column)
								let subSamplePixelLocation:[Point] = subSampleLocations.map({ inverseTransform.transform($0) })
								let hitColors:[SampledColor] = subSamplePixelLocation.compactMap { (point) -> SampledColor? in
									return !crudeStrokingPath.isPoint(point, within: halfLineWidth) ? nil : shader.color(at: point)
								}
								if hitColors.count == 0 { continue }
								let antialiasRatio:Float32 = 1.0/Float32(subSampleLocations.count)
								let antialiases:[(SampledColor, Float32)] = hitColors.map({ ($0, antialiasFactor:antialiasRatio)})
								let underValue:SampledColor = underlyingImage[column, row]
								underlyingImage[column, row] = underlyingImage.colorSpace.composite(source:antialiases, over: underValue)
							}
						}
					}
				}
			}

//		case .triangulation:
//			//idea is to break down the pixel into two triangles, then use geometry to perfectly calculate the affected triangles
//			//TODO: write me
//			break
		}
	}
	
	
	struct PixelTriangleCoordinate : Hashable {
		var row:Int
		var column:Int
		
		func hash(into hasher: inout Hasher) {
			row.hash(into: &hasher)
			column.hash(into: &hasher)
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
			let newTransformation = oldTransformation.concatenate(with:transformation)
			context.states[context.states.count-1].transformation = newTransformation
		}
		
		init(context:SampledGraphicsContext) {
			self.context = context
		}
		
		private weak var context:SampledGraphicsContext?
		
	}
	
	
	public func drawImage(_ image:SampledImage, in rect:Rect) {
		guard let interpolator = try? interpolation.init(image, into: underlyingImage, in: rect, transform: currentState.transformation) else { return }
		interpolator.perform()
	}
	
	
	public func drawText(_ text: String, font: RenderingFont, fillShader: Shader?, stroke:StrokeOptions?) {
		let glyphsIndexes:[Int] = font.gylphIndexes(text: text)
		let advances:[SGFloat] = font.glyphAdvances(indices: glyphsIndexes)
		let glyphs:[Path] = glyphsIndexes.map({ font.path(glyphIndex: $0) })
		
		var coord:Point = Point(x: 0.0, y: 0.0)
		for (i, glyph) in glyphs.enumerated() {
			drawPath(Transform2D(translateX: coord.x, y: coord.y).transform(glyph)
				,fill:fillShader.flatMap({ FillOptions(shader: $0, subPathOverlapping: .windingNumber) })
				,stroke: stroke)
			coord.x += advances[i]
		}
	}
	
	public var interpolation:SampledImageInterpolation.Type = BicubicInterpolation.self
	
}
