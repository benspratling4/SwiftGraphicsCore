//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/29/20.
//

import Foundation


struct Matrix : Equatable {
	///m
	var rows:Int
	
	///n
	var columns:Int
	
	///omit the values to get init'd at the right size and all 0's
	///or provide the intial values
	///  ⎡ a b c ⎤
	///  | d e f |
	///  ⎣ g h i ⎦
	///
	///would be init(rows:3, columns:3, values:[a, b, c, d, e, f, g, h, i])
	init(rows:Int, columns:Int, values:[SGFloat]? = nil) {
		self.rows = rows
		self.columns = columns
		self.values = values ?? [SGFloat](repeating:0, count: rows * columns)
	}
	
	init(diagonal:[SGFloat]) {
		let c:Int = diagonal.count
		self.rows = c
		self.columns = c
		self.values = [SGFloat](repeating:0, count: c * c)
		for i in 0..<c {
			values[i*c + i] = diagonal[i]
		}
	}
	
	///creates a square matrix
	init(identity:Int) {
		let diagonal = [SGFloat](repeating: 1, count: identity)
		let c:Int = diagonal.count
		self.rows = c
		self.columns = c
		self.values = [SGFloat](repeating:0, count: c * c)
		for i in 0..<c {
			values[i*c + i] = diagonal[i]
		}
	}
	
	init(columnVector:[SGFloat]) {
		self.rows = columnVector.count
		self.columns = 1
		self.values = columnVector
	}
	
	private var values:[SGFloat]
	
	subscript(row: Int, column: Int) -> Double {
		get {
			return values[(row * columns) + column]
		}
		set {
			values[(row * columns) + column] = newValue
		}
	}
	
	var transpose:Matrix {
		var result:Matrix = Matrix(rows:columns, columns:rows)
		for row in 0..<rows {
			for column in 0..<columns {
				result[column, row] = self[row, column]
			}
		}
		return result
	}
	
	///lhs.columns == rhs.rows
	//result has lhs.rows and rhs.columns
	static func *(lhs:Matrix, rhs:Matrix)->Matrix {
		var result = Matrix(rows:lhs.rows, columns:rhs.columns)
		let productIteration:Int = lhs.columns
		for row in 0..<lhs.rows {
			for column in 0..<rhs.columns {
				var sum:SGFloat = 0
				for i in 0..<productIteration {
					 sum += lhs[row, i] * rhs[i, column]
				}
				result[row, column] = sum
			}
		}
		return result
	}
	
	
	static func ==(lhs:Matrix, rhs:Matrix)->Bool {
		guard lhs.rows == rhs.rows, lhs.columns == rhs.columns else { return false }
		for i in 0..<lhs.values.count {
			if lhs.values[i] != rhs.values[i] {
				return false
			}
		}
		return true
	}
	
	/*
	func row(_ i:Int)->[SGFloat] {
		var newRows = [Int](repeating:0, count:)
	}
	
	func column(_ i:Int)->[SGFloat] {
		
	}
	*/
	
}
