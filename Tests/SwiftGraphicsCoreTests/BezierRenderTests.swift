//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/3/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore

class BezierRenderTests : XCTestCase {
	
	func testSimpleBezierRender() {
		let colorSpace:ColorSpace = GenericRGBAColorSpace(hasAlpha: true)
		
		let size:SGFloat = 8
		
		let context = SampledGraphicsContext(dimensions: Size(width: size, height: size), colorSpace: colorSpace)
		
		var path:Path = Path(subPaths: [])
			.byMoving(to:Point(x: 0.0, y: size/2.0))
		path.addCurve(near:Point(x: size/2.0, y: size)
			,and:Point(x: size/2.0, y: 0.0)
			,to:Point(x: size, y: size/2.0))
		context.drawPath(path, fillShader: SolidColorShader(color: colorSpace.black), stroke: nil)
	}
	
}
