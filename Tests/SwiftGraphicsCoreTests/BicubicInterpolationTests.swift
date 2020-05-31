//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/29/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore




class BicubicInterpolationTests : XCTestCase {
	
	func testSimpleInterpolation() {
		let colorSpace:ColorSpace = GenericRGBAColorSpace(hasAlpha: true)
		let originalImage = SampledImage(width: 2, height: 2, colorSpace: colorSpace, bytes: [
			255,0,0,255,
			255,255,0,255,
			0,255,0,255,
			0,0,255,255])
		
		
	}
	
	
}
