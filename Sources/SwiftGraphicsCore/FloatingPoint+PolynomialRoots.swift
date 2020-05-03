//
//  File.swift
//  
//
//  Created by Ben Spratling on 5/3/20.
//

import Foundation

extension FloatingPoint {
	
	var multipliableSign:Self {
		switch sign {
		case .plus:
			return Self(1)
		case .minus:
			return Self(-1)
		}
	}
	
}


//real unique solutions to the equation ax^2 + bx + c == 0
func realQuadraticRoots(a:SGFloat, b:SGFloat, c:SGFloat)->[SGFloat] {
	if a == 0 {
		//can't divide by 0
		return []
	}
	let rand:SGFloat = pow(b, 2) - 4 * a * c
	if rand < 0 {
		//no real solutions
		return []
	}
	if rand == 0 {
		//one real solution
		return [-b/(2 * a)]
	}
	//two real solutions
	let sol0:SGFloat = (-b - sqrt(rand))/(2 * a)
	let sol1:SGFloat = (-b + sqrt(rand))/(2 * a)
	return [sol0, sol1]
}

///solutions to x for the equation ax^3 + bx^2 + cx + d == 0
func realCubeRoots(a:SGFloat, b:SGFloat, c:SGFloat, d:SGFloat)->[SGFloat] {
	if a == 0.0 {
		return realQuadraticRoots(a: b, b: c, c: d)
	}
	let A:SGFloat = b/a
	let B:SGFloat = c/a
	let C:SGFloat = d/a
	
	let Q:SGFloat = (3.0 * B - pow(A, 2))/9.0
	let R:SGFloat = (9.0 * A * B - 27.0 * C - 2.0 * pow(A, 3))/54.0
	let D:SGFloat = pow(Q, 3) + pow(R, 2)	//polynomial discriminant
	
	if D >= 0.0 {
		//complex or duplicate roots
		let rootD:SGFloat = sqrt(D)
		let RPlusRootD:SGFloat = R + rootD
		let S:SGFloat = RPlusRootD.multipliableSign * pow(abs(RPlusRootD), 1.0/3.0)
		let RMinusRootD:SGFloat = R - rootD
		let T:SGFloat = RMinusRootD.multipliableSign * pow(abs(RMinusRootD), 1.0/3.0)
		
		let realRoot = -A/3.0 + (S + T)
		guard abs(sqrt(3) * (S-T)/2.0) <= 0.00001 else {
			return [realRoot]
		}
		let imagRoot0 = -A/3.0 - (S + T)/2.0
//		let imagRoot1 = -A/3.0 - (S + T)/2.0	//duplicate
		return [realRoot, imagRoot0]
		
	} else {
		//distinct real roots
		let th = acos(R/sqrt(-pow(Q,3.0)))
		let sqrtNegQ = sqrt(-Q)
		return [
			2.0 * sqrtNegQ * cos(th/3.0) - A/3.0,
			2.0 * sqrtNegQ * cos((th+2.0*SGFloat.pi)/3.0) - A/3.0,
			2.0 * sqrtNegQ * cos((th+4.0*SGFloat.pi)/3.0) - A/3.0,
		]
	}
	
}
