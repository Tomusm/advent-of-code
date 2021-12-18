#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	fileURL.processLineByLine { (line: String) in
		let cleanedUpString = line.replacingOccurrences(of: "target area: ", with: "").replacingOccurrences(of: "x=", with: "").replacingOccurrences(of: "y=", with: "")
		
		let components = cleanedUpString.components(separatedBy: ", ").map { $0.components(separatedBy: "..").compactMap { Int($0) } }

		let xPoints = components[0]
		
		let xMin = xPoints.min()!
		let xMax = xPoints.max()!
		print(xMin, xMax)

		let yPoints = components[1]

		let yMin = yPoints.min()!
		let yMax = yPoints.max()!
		print(yMin, yMax)


		// Get max possible Y velocity
		let highestPointY = (abs(yMin) - 1)*abs(yMin)/2
		print("Part 1 answer: Max Y velocity \(highestPointY)")
		
		var count = 0
		// Works because the range Y is negative
		let extremeY = max(abs(yMin), abs(yMax))
		let xRange = (min(xMin, 0)...(max(0, xMax)))
		for yVelocity in (extremeY * -1)...abs(extremeY) {
			for xVelocity in xRange {
				let reachTarget = simulate(velocity: (xVelocity, yVelocity), targetX: (xMin, xMax), targetY: (yMin, yMax))
				if reachTarget {
					count += 1
				}
			}
		}

		print("COUNT \(count)")
		
	}
} catch {
	print(error)
}

func simulate(velocity: (x: Int, y: Int), targetX: (xMin: Int, xMax: Int), targetY: (yMin: Int, yMax: Int)) -> (Bool) {
	var currentPosition = (x: 0, y: 0)
	let xMin = targetX.xMin
	let xMax = targetX.xMax
	let yMin = targetY.yMin
	let yMax = targetY.yMax

	var currentVelocity = velocity 
	while (abs(currentPosition.x) <= max(abs(xMax), abs(xMin)) && currentPosition.y >= yMin) {
		currentPosition = (currentPosition.x + currentVelocity.x, currentPosition.y + currentVelocity.y)

		if (currentPosition.x >= xMin && currentPosition.x <= xMax) && (currentPosition.y >= yMin && currentPosition.y <= yMax) {
			return true
		}

		if currentVelocity.x == 0 {
			currentVelocity = (0, currentVelocity.y - 1)
		} else {
			let nextX = currentVelocity.x > 0 ? currentVelocity.x - 1 : currentVelocity.x + 1
			currentVelocity = (nextX, currentVelocity.y - 1)
		}

	}

	return false
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
