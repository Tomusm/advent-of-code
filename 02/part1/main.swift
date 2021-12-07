#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

enum Direction {
	case forward(Int)
	case down(Int)
	case up(Int)

	init?(string: String) {
		var string = string
		if let range = string.range(of: "forward ") {
			string.removeSubrange(range)
			self = .forward(Int(string)!)
		}
		else if let range = string.range(of: "down ") {
			string.removeSubrange(range)
			self = .down(Int(string)!)
		}
		else if let range = string.range(of: "up ") {
			string.removeSubrange(range)
			self = .up(Int(string)!)
		} else {
			return nil
		}
	}

	static func resolve(_ directions: [Direction]) -> (position: Int, depth: Int) {
		var position = 0
		var depth = 0

		for direction in directions {
			switch direction {
				case forward(let value):
					position += value
				case down(let value):
					depth += value
				case up(let value):
					depth -= value
			}
		}

		return (position, depth)
	}
}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]


	var directions = [Direction]()
	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		let direction = Direction(string: line)!
		directions.append(direction)
	}

	let resolve = Direction.resolve(directions)

	print("\(resolve.position*resolve.depth)")
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