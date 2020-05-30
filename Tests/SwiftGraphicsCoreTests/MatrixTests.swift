//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/29/20.
//

import Foundation
import XCTest
@testable import SwiftGraphicsCore


class MatrixTests : XCTestCase {
	
	func testEquivalence() {
		//matrices are not equal if the dimensions don't match, even if the 
		let a:Matrix = Matrix(rows:1, columns:3, values:[1, 2, 3])
		let b:Matrix = Matrix(rows:3, columns:1, values:[1, 2, 3])
		XCTAssertNotEqual(a, b)
		XCTAssertEqual(a, a)		
	}
	
	func testIdentity() {
		let identity = Matrix(diagonal: [1, 1, 1])
		let psuedoIdentity = Matrix(rows: 3, columns: 3, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
		XCTAssertEqual(identity, psuedoIdentity)
	}
	
	func testMultiply() {
		//simple identity test
		let vector = Matrix(columnVector: [10, 11, 12])
		XCTAssertEqual(Matrix(identity:3)*vector, vector)
		
		//larger matrix test
		let matrix = Matrix(rows: 3, columns: 3, values: [1, 2, 3, 4, 5, 6, 7, 8, 9])
		let product = matrix * vector
		XCTAssertEqual(product, Matrix(columnVector: [68, 167, 266]))
	}
	
	
}
