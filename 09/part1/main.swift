#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

enum Direction: CaseIterable {
	case up
	case down
	case left
	case right
}

struct HeightPoint {

	let value: Int
	var lowestInDirection = Set<Direction>()

	func verify() -> Bool {
		if (lowestInDirection == Set(Direction.allCases)) {
			return true
		} else {
			return false
		}
	}
}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	var count = 0

	var riskLevel = 0
	var beforeLine: [HeightPoint]?
	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		let values = line.map { String($0) }.compactMap { Int($0) }

		var currentLine = [HeightPoint]()
		for (index, value) in values.enumerated() {
			// First line case
			var lowest = Set<Direction>()
			if (beforeLine == nil) {
				lowest.insert(.up)
			} else {
				if (value < beforeLine![index].value) {
					lowest.insert(.up)
				} else {
					beforeLine![index].lowestInDirection.insert(.down)
				}
			}

			if (index == 0) {
				lowest.insert(.left)
			} else {
				if (value < values[index - 1]) {
					lowest.insert(.left)
				} else {
					currentLine[index - 1].lowestInDirection.insert(.right)
				}
			}
			
			
			if (index == values.count - 1) {
				lowest.insert(.right)
			}

			currentLine.append(HeightPoint(value: value, lowestInDirection: lowest))
		}

		if let beforeLine = beforeLine {
			for heightPoint in beforeLine {
				if (heightPoint.verify() == true) {
					riskLevel += 1 + heightPoint.value
				}
			}
		}

		beforeLine = currentLine
	}

	for var heightPoint in beforeLine! {
		heightPoint.lowestInDirection.insert(.down)
		if (heightPoint.verify() == true) {
			riskLevel += 1 + heightPoint.value
		}
	}
	
	print(riskLevel)

} catch {
	print("error")
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
