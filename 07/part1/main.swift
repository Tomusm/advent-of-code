#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

	func diff(average: Int, dict: [Int: Int], before: Bool, max: Int) -> (totalDiff: Int, closest: Int) {
		// Look before and after
		var afterClosest = 0
		var afterDiff = Int.max
		var totalDiffAfter = 0
		for position in (average...max) {
			guard let value = dict[position] else {
				continue
			}

			totalDiffAfter += (abs(average - position) * value)

			let diff = abs(average - position) / value
			if (diff < afterDiff) {
				afterClosest = position
				afterDiff = diff
			}
		}

		var beforeClosest = 0
		var beforeDiff = Int.max
		var totalDiffBefore = 0
		for position in 0..<average {
			guard let value = dict[position] else {
				continue
			}

			totalDiffBefore += (abs(average - position) * value)

			let diff = abs(average - position) / value
			if (diff < beforeDiff) {
				beforeClosest = position
				beforeDiff = diff
			}
		}

		let closest = (before == true) ? beforeClosest : afterClosest
		return (totalDiffBefore + totalDiffAfter, closest)
	}

	func lowestDiff(inDict dict: [Int: Int], before: Bool, startingValue value: Int, maxPosition: Int) -> Int {
		var totalDiff = Int.max
		var startingValue = value
		while true {
			let result = diff(average: startingValue, dict: dict, before: before, max: maxPosition)
			if (result.totalDiff < totalDiff) {
				totalDiff = result.totalDiff
			} else {
				break
			}

			startingValue = result.closest
		}

		return totalDiff
	}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	var count = 0

	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		let positions = line.components(separatedBy: ",").compactMap { Int($0) }

		// Sort in dict
		var total = 0
		var dict = [Int: Int]()
		var maxPosition = 0
		for position in positions {
			if maxPosition < position {
				maxPosition = position
			}

			total += position
			dict[position] = (dict[position] ?? 0) + 1
		}

		let average = total / positions.count

		let lowestDiffBefore = lowestDiff(inDict: dict, before: true, startingValue: average, maxPosition: maxPosition)

		let lowestDiffAfter = lowestDiff(inDict: dict, before: false, startingValue: average, maxPosition: maxPosition)

		let result = lowestDiffBefore < lowestDiffAfter ? lowestDiffBefore : lowestDiffAfter
		print("Total fuel \(result)")
	}
} catch {
	fatalError("""

	-----------------------------------
	ERROR: \(error)
	-----------------------------------

	""")
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
