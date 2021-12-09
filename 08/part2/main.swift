#!/usr/bin/env xcrun --sdk macosx swift

import Foundation
	
do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	var totalOutput = 0

	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		let components = line.components(separatedBy: " | ")
		var patterns = Set(components[0].components(separatedBy: " ").map { Set($0.map { String($0) }) })
		let outputValues = components[1].components(separatedBy: " ").map { Set($0.map { String($0) }) }

		var one, four, seven, eight: Set<String>!
		for pattern in patterns {
			if (pattern.count == 2) {
				one = pattern
			} else if (pattern.count == 4) {
				four = pattern
			} else if (pattern.count == 3) {
				seven = pattern
			} else if (pattern.count == 7) {
				eight = pattern
			}
		}

		patterns.remove(one)
		patterns.remove(four)
		patterns.remove(seven)
		patterns.remove(eight)

		// We can know which one is six because it has 6 count, and contains only one element from one
		let six: Set<String> = {
			return patterns.filter { $0.count == 6 }.first { one.intersection($0).count == 1 }!
		}()

		patterns.remove(six)

		// Only "c" is missing from six, by comparing what rests after comparing six and one, we get -> "c"
		let c = one.subtracting(six).first!
		// f is the other letter in one -> f
		let f = one.subtracting([c]).first!

		// We know c and f, so we can know which ones are b or d by using 4.
		let bAndD = four.subtracting([c, f])

		// Zero has 6 count, and doesn't contain D but contains B. We can guess 0 like this.
		let zero: Set<String> = {
			return patterns.filter { $0.count == 6 }.first { ($0.intersection(bAndD).count == 1) }!
		}()

		patterns.remove(zero)

		// The letter in common in zero with bAndD is b
		let b = zero.intersection(bAndD).first!

		// Nine is the remaining one with 6 count
		let nine = patterns.filter { $0.count == 6 }.first!

		patterns.remove(nine)

		// Two is the only with count 5 without B and F (that we know)
		let bAndF = Set([b, f])
		let two = patterns.filter { $0.count == 5 }.first { $0.intersection(bAndF).isEmpty == true }!

		patterns.remove(two)

		// Three is the only remaining (5 count) which misses B
		let three = patterns.first { $0.intersection(Set([b])).isEmpty == true }!
		patterns.remove(three)
		
		// Five is the last one
		let five = patterns.first!

		let resultArray: [String] = outputValues.map { (values: Set<String>) in
			if (values == zero) {
				return "0"
			} else if (values == one) {
				return "1"
			} else if (values == two) {
				return "2"
			} else if (values == three) {
				return "3"
			} else if (values == four) {
				return "4"
			} else if (values == five) {
				return "5"
			} else if (values == six) {
				return "6"
			} else if (values == seven) {
				return "7"
			} else if (values == eight) {
				return "8"
			} else if (values == nine) {
				return "9"
			}

			return "ERROR"
		}

		let resultString = resultArray.reduce("") { (result: String, digit: String) in
			return "\(result)\(digit)"
		}

		let result = Int(resultString)!

		totalOutput += result
	}

	print(totalOutput)

} catch {
	print(error)
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
