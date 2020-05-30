//
//  BicubicInterpolation.swift
//  
//
//  Created by Ben Spratling on 5/29/20.
//

import Foundation





public struct BicubicInterpolation : SampledImageInterpolation {
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
		
		//inefficient algorithm first, to prove concept
		
		//find the original pixel coordinates
		
		//for each pixel, if it's in the original image, find its coordinates
		for pixelX in pixelXMin...pixelXMax {
			for pixelY in pixelYMin...pixelYMax {
				let point:Point = Point(x: SGFloat(pixelX) + 0.5, y: SGFloat(pixelY) + 0.5)
				guard support.isPointInOriginalImage(point) else { continue }
				let transformedCoords:Point = support.inverseTransform.transform(point)
				//now get the coords of the nearest pixel
				let xMin:SGFloat = (transformedCoords.x-0.5).rounded(.down)
				let yMin:SGFloat = (transformedCoords.y-0.5).rounded(.down)
				let originalX:Int = Int(xMin)
				let originalY:Int = Int(yMin)
				
//				guard originalX >= 0, originalX < image.dimensions.width, originalY >= 0, originalY < image.dimensions.width else { continue }
				
				
				//get the bicubic setup for the red, green, blue and alpha
				//we have to interpolate in 4 colors, red, green, blue and alpha
				
				let xs:[Int] = [-1, 0, 1, 2].map({ max(0, min(image.dimensions.width-1, originalX + $0)) })	//repeat values at edges
				let ys:[Int] = [-1, 0, 1, 2].map({ max(0, min(image.dimensions.height-1, originalY + $0)) })
				
				let dx = transformedCoords.x - xMin - 0.5
				let dy = transformedCoords.y - yMin - 0.5
				
				let coordinates:[(Int, Int)] = xs.map({ x in ys.map({ y in (x, y) }) }).flatMap({ $0 })
				let colors:[Color] = coordinates.map({ image.colorSpace.toAbstractRGB(image[$0, $1]) })
				
				let componentSetups:[BicubicInterpolationSetup] = [Int](0..<image.colorSpace.componentCount).map {
					return BicubicInterpolationSetup(x0y0:SGFloat(colors[0].components[$0])
						, x0y1: SGFloat(colors[1].components[$0])
						, x0y2: SGFloat(colors[2].components[$0])
						, x0y3: SGFloat(colors[3].components[$0])
						, x1y0: SGFloat(colors[4].components[$0])
						, x1y1: SGFloat(colors[5].components[$0])
						, x1y2: SGFloat(colors[6].components[$0])
						, x1y3: SGFloat(colors[7].components[$0])
						, x2y0: SGFloat(colors[8].components[$0])
						, x2y1: SGFloat(colors[9].components[$0])
						, x2y2: SGFloat(colors[10].components[$0])
						, x2y3: SGFloat(colors[11].components[$0])
						, x3y0: SGFloat(colors[12].components[$0])
						, x3y1: SGFloat(colors[13].components[$0])
						, x3y2: SGFloat(colors[14].components[$0])
						, x3y3: SGFloat(colors[15].components[$0])
						)
				}
				
				let values = componentSetups.map({ $0.value(x: dx, y: dy) })
				let color = image.colorSpace.fromAbstractRGB(Color(components: values.map({ Float32($0) })))
				
				let destinationColor = destination[pixelX, pixelY]
				let composited = image.colorSpace.composite(source: [(color, antialiasFactor: 1.0)], over: destinationColor)
				destination[pixelX, pixelY] = composited
			}
		}
	}
}


//pure mathematical bicubic interpolation
struct BicubicInterpolationSetup {
	//init with the values surrounding the unit square into which we want to interpolate the values
	init(x0y0:SGFloat, x0y1:SGFloat, x0y2:SGFloat, x0y3:SGFloat, x1y0:SGFloat, x1y1:SGFloat, x1y2:SGFloat, x1y3:SGFloat, x2y0:SGFloat, x2y1:SGFloat, x2y2:SGFloat, x2y3:SGFloat, x3y0:SGFloat, x3y1:SGFloat, x3y2:SGFloat, x3y3:SGFloat) {
		
		let fdxx0y0:SGFloat = ((x2y1 - x0y1))/2.0
		let fdxx0y1:SGFloat = ((x2y2 - x0y2))/2.0
		let fdxx1y0:SGFloat = ((x3y1 - x1y1))/2.0
		let fdxx1y1:SGFloat = ((x3y2 - x1y2))/2.0
		
		let fdyx0y0:SGFloat = ((x1y2 - x1y0))/2.0
		let fdyx0y1:SGFloat = ((x1y3 - x1y1))/2.0
		let fdyx1y0:SGFloat = ((x2y2 - x2y0))/2.0
		let fdyx1y1:SGFloat = ((x2y3 - x2y1))/2.0
		
		let fdxdyx0y0:SGFloat = (((x2y2 - x0y2))/2.0 - ((x2y0 - x0y0))/2.0)/2.0
		let fdxdyx0y1:SGFloat = (((x2y3 - x0y3))/2.0 - ((x2y1 - x0y1))/2.0)/2.0
		let fdxdyx1y0:SGFloat = (((x3y2 - x1y2))/2.0 - ((x3y0 - x1y0))/2.0)/2.0
		let fdxdyx1y1:SGFloat = (((x3y3 - x1y3))/2.0 - ((x3y1 - x1y1))/2.0)/2.0
		
		let f:Matrix = Matrix(rows: 4, columns: 4, values: [
			 x1y1, x1y2, fdyx0y0, fdyx0y1,
			 x2y1, x2y2, fdyx1y0, fdyx1y1,
			 fdxx0y0, fdxx0y1, fdxdyx0y0, fdxdyx0y1,
			 fdxx1y0, fdxx1y1, fdxdyx1y0, fdxdyx1y1
		])
		
		Ainverse = crazyCoefficientmatrixTransposed * f * crazyCoefficientMatrix
	}
	
	let Ainverse:Matrix
	
	///x and y are 0...1,
	func value(x:SGFloat, y:SGFloat)->SGFloat {
		let xSquared:SGFloat = x * x
		let xCubed:SGFloat = xSquared * x
		
		let ySquared:SGFloat = y * y
		let yCubed:SGFloat = ySquared * y
		
		return (Matrix(rows: 1, columns: 4, values: [1, x, xSquared, xCubed]) * (Ainverse * Matrix(columnVector: [1, y, ySquared, yCubed]) ))[0,0]
	}
	
}

private let crazyCoefficientMatrix:Matrix = Matrix(rows: 4, columns: 4, values: [
	 1, 0,-3, 2,
	 0, 0, 3,-2,
	 0, 1,-2, 1,
	 0, 0, -1, 1
])

private let crazyCoefficientmatrixTransposed:Matrix = crazyCoefficientMatrix.transpose
