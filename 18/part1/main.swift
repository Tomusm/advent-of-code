#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)
	var currentPair: Pair?

	fileURL.processLineByLine { (line: String) in
		let pair = PairBuilder.build(from: line)
		if let _currentPair = currentPair {
			// ADD
			currentPair = _currentPair.add(pair)
			var continueResolve = true
			while continueResolve {
				let explosions = currentPair!.resolveExplosion()
				if (explosions == false) {
					continueResolve = currentPair!.resolveSplit()
				}
			}
		} else {
			currentPair = pair
		}
	}

	print(currentPair!.magnitude)
} catch {
	print(error)
}

enum PairValue {

	case pair(Pair)
	case integer(Int)

	var description: String {
		switch self {
		case .pair(let pair):
			return pair.description
		case .integer(let int): 
			return "\(int)"
		}
	}

	var integer: Int? {
		switch self {
		case .pair:
			return nil
		case .integer(let int): 
			return int
		}
	}

	var pair: Pair? {
		switch self {
		case .pair(let pair):
			return pair
		case .integer: 
			return nil
		}
	}
}

enum PairBuilder {

	static func build(from string: String) -> Pair {
		return self.build(from: string.map { String($0) }).0.pair!
	}

	static private func build(from strings: [String]) -> (PairValue, [String]) {
		var strings = strings
		var left: PairValue?
		var right: PairValue?
		let char = strings.removeFirst()
		if (char == "[") {
			// OK
			if (strings.first == "[") {
				// Sub pair
				let result = build(from: strings)
				left = result.0
				strings = result.1

				// remove comma
				strings.removeFirst()
				// Check next char
				if (strings.first == "[") {
					// Sub pair
					let result = build(from: strings)
					right = result.0
					strings = result.1
					// remove closing ]
					strings.removeFirst()
				} else {
					right = .integer(Int(strings.removeFirst())!)
					// remove closing ]
					strings.removeFirst()
				}
			} else {
				left = .integer(Int(strings.removeFirst())!)
				// remove comma
				strings.removeFirst()

				// Check next char
				if (strings.first == "[") {
					// Sub pair
					let result = build(from: strings)
					right = result.0
					strings = result.1
					// remove closing ]
					strings.removeFirst()
				} else {
					right = .integer(Int(strings.removeFirst())!)
					// remove closing ]
					strings.removeFirst()
				}
			}
		}

		let pair = Pair(left!, right!)
		return (.pair(pair), strings)
	}
}

class Pair: Equatable {

	private enum Direction {
		case left
		case right
	}

	var parent: Pair?
	let id = UUID()

	var left: PairValue {
		didSet {
			left.pair?.parent = self
		}
	}

	var right: PairValue {
		didSet {
			right.pair?.parent = self
		}
	}

	var magnitude: Int {
		let left: Int = {
			if let integer = self.left.integer {
				return integer
			} else {
				return self.left.pair!.magnitude
			}
		}()

		let right: Int = {
			if let integer = self.right.integer {
				return integer
			} else {
				return self.right.pair!.magnitude
			}
		}()

		return (3 * left) + (2 * right)
	}

	var description: String {
		return "[\(self.left.description),\(self.right.description)]"
	}

	static func ==(lhs: Pair, rhs: Pair) -> Bool {
		(lhs.description == rhs.description) && (lhs.parent == rhs.parent) && (lhs.id == rhs.id)
	}


	init(_ left: PairValue, _ right: PairValue) {
		self.left = left
		self.right = right
				
		self.left.pair?.parent = self
		self.right.pair?.parent = self
	}

	private func pairValue(direction: Direction) -> PairValue {
		switch direction {
			case .left:
				return self.left
			case .right:
				return self.right
		}
	}

	private func setPairValue(_ pairValue: PairValue, direction: Direction) {
		switch direction {
			case .left:
				self.left = pairValue
			case .right:
				self.right = pairValue
		}
	}

	private func findPreviousLeftInt(from: Pair) -> (Pair, Direction)? {
		if let _ = self.left.integer {
			return (self, .left)
		} else {
			if (from == self.left.pair!) {
				return self.parent?.findPreviousLeftInt(from: self)
			} else {
				return (self.left.pair!.firstRightInt(), .right)
			}
		}
	}

	private func findNextRightInt(from: Pair) -> (Pair, Direction)? {
		if let _ = self.right.integer {
			return (self, .right)
		} else {
			if from == self.right.pair! {
				return self.parent?.findNextRightInt(from: self)
			} else {
				// We need to dive in self.right to find the first int
				return (self.right.pair!.firstLeftInt(), .left)
			}
		}
	}

	private func firstLeftInt() -> Pair {
		if let _ = self.left.integer {
			return self
		} else {
			return self.left.pair!.firstLeftInt()
		}
	}

	private func firstRightInt() -> Pair {
		if let _ = self.right.integer {
			return self
		} else {
			return self.right.pair!.firstRightInt()
		}
	}

	func add(_ right: Pair) -> Pair {
		return Pair(.pair(self), .pair(right))
	}

	func resolveExplosion(deep: Int = 1) -> Bool {
		if let pair = self.left.pair {
			if (deep == 4) {
				// EXPLODE
				self.applyExplodeToNeigborValues(forExplodingPair: pair)
				self.left = .integer(0)
				return true
			} else {
				let resolved = pair.resolveExplosion(deep: deep + 1)
				if resolved == true {
					return true
				}
			}
		}

		if let pair = self.right.pair {
			if (deep == 4) {
				// EXPLODE
				self.applyExplodeToNeigborValues(forExplodingPair: pair)
				self.right = .integer(0)
				return true
			} else {
				let resolved = pair.resolveExplosion(deep: deep + 1)
				if resolved == true {
					return true
				}
			}
		} 

		return false
	}

	func resolveSplit() -> Bool {
		if let integer = self.left.integer {
			if (integer > 9) {
				// SPLIT
				self.left = self.splitedValue(from: integer)
				return true
			}
		} else {
			let resolved = self.left.pair!.resolveSplit()
			if (resolved == true) {
				return true
			}
		}
		
		if let integer = self.right.integer {
			if (integer > 9) {
				// SPLIT
				self.right = self.splitedValue(from: integer)
				return true
			}
		} else {
			let resolved = self.right.pair!.resolveSplit()
			if (resolved == true) {
				return true
			}
		}

		return false
	}


	private func splitedValue(from integer: Int) -> PairValue {
		let left = (integer / 2)
		let right = (integer % 2) == 0 ? (integer / 2) : ((integer / 2) + 1)
		return .pair(Pair(.integer(left), .integer(right)))
	}

	private func applyExplodeToNeigborValues(forExplodingPair explodingPair: Pair) {
		if let leftParentAndDirection = self.findPreviousLeftInt(from: explodingPair) {
			let parent = leftParentAndDirection.0
			let direction = leftParentAndDirection.1
			let valueForDirection = parent.pairValue(direction: direction)
			parent.setPairValue(.integer(valueForDirection.integer! + explodingPair.left.integer!), direction: direction)
		}

		if let rightParentAndDirection = self.findNextRightInt(from: explodingPair) {
			let parent = rightParentAndDirection.0
			let direction = rightParentAndDirection.1
			let valueForDirection = parent.pairValue(direction: direction)
			parent.setPairValue(.integer(valueForDirection.integer! + explodingPair.right.integer!), direction: direction)
		}
	}
}

enum ScriptError: Error {
	case arguments
}

extension URL {
	
	func processLineByLine(processLine: @escaping (_ line: String) -> ()) {
		
		/// Open the file for reading.
		/// Note: user should be prompted the first time to allow reading from this location.
		guard let filePointer: UnsafeMutablePointer<FILE> = fopen(self.path, "r") else {
			preconditionFailure("Could not open file at \(self.absoluteString)")
		}
		
		defer {
			/// Remember to close the file when done.
			fclose(filePointer)
		}
		
		/// A pointer to a null-terminated, UTF-8 encoded sequence of bytes.
		var lineByteArrayPointer: UnsafeMutablePointer<CChar>? = nil
		
		/// The smallest multiple of 16 that will fit the byte array for this line.
		var lineCap: Int = 0
		
		/// Define nextLine as closure, because we need to use it twice.
		let nextLine = {
			/// For details regarding `getline()` have a look at
			/// https://www.man7.org/linux/man-pages/man3/getline.3.html
			return getline(&lineByteArrayPointer, &lineCap, filePointer)
		}

		defer {
			/// If *lineptr is set to NULL before the call, then getline() will
			/// allocate a buffer for storing the line.  This buffer should be
			/// freed by the user program even if getline() failed.
			lineByteArrayPointer?.deallocate()
		}
		
		/// Initial iteration.
		var bytesRead = nextLine()
		
		while (bytesRead > 0) {
			guard let linePointer = lineByteArrayPointer else {
				break
			}
			
			/// Note: this translates the sequence of bytes to a string
			/// using the UTF-8 encoding for interpreting byte sequences.
			var lineString = String.init(cString: linePointer)
			
			/// `lineString` initially includes the newline character, if one was found.
			if lineString.last?.isNewline == true {
				lineString = String(lineString.dropLast())
			}
			
			/// Process this single line of text.
			processLine(lineString)
			
			/// Update number of bytes read and the pointers for the next iteration.
			bytesRead = nextLine()
		}
	}
	
}
