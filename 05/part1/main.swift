#!/usr/bin/env xcrun --sdk macosx swift

import Foundation


struct IntPoint {
	let x: Int
	let y: Int
}


do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

			// y: x : amount
	var matrix = [Int: [Int: Int]]()

	var count = 0

	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		let numbers = line.components(separatedBy: " -> ").flatMap { $0.components(separatedBy: ",") }.compactMap { Int($0) }
		let departure = IntPoint(x: numbers[0], y: numbers[1])
		let arrival = IntPoint(x: numbers[2], y: numbers[3])
		if (departure.x == arrival.x) {

			for i in min(departure.y, arrival.y)...max(departure.y, arrival.y) {
				var yDict = matrix[i] ?? [Int: Int]()
				var value = (yDict[departure.x] ?? 0)
				value += 1
				yDict[departure.x] = value
				matrix[i] = yDict
				if (value == 2) {
					count += 1
				}
			}
		} else if (departure.y == arrival.y) {
			for i in min(departure.x, arrival.x)...max(departure.x, arrival.x) {
				var yDict = matrix[departure.y] ?? [Int: Int]()
				var value = (yDict[i] ?? 0)
				value += 1
				yDict[i] = value
				matrix[departure.y] = yDict

				if (value == 2) {
					count += 1
				}
			}
		}
	}

	print(count)

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
