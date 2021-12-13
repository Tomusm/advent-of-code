#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)
	// grid[y][x]
	var grid = [[Int]]()
	fileURL.processLineByLine { (line: String) in
		let gridLine = line.map { String($0) }.compactMap { Int($0) }
		grid.append(gridLine)
	}

	// We know it's a square
	let objective = grid.count * grid.count
	var stepCount = 0
	while (true) {
		stepCount += 1
		let step = triggerStep(forGrid: grid)
		grid = step.grid
		if (step.flashCount == objective) {
			break
		}
	}

	print(stepCount)

} catch {
	print(error)
}

struct IntPoint: Hashable {
	let x: Int
	let y : Int
}

func triggerStep(forGrid grid: [[Int]]) -> (grid: [[Int]], flashCount: Int) {
	var flashes = Set<IntPoint>()
	var grid = grid
	for (y, line) in grid.enumerated() {
		for (x, var energyLevel) in line.enumerated() {
			energyLevel += 1
			if energyLevel > 9 {
				flashes.insert(IntPoint(x: x, y: y))
			}

			grid[y][x] = energyLevel
		}
	}

	return processFlashes(flashes, inGrid: grid)
}

func processFlashes(_ flashes: Set<IntPoint>, inGrid grid: [[Int]], alreadyFlashed: Set<IntPoint> = Set<IntPoint>()) -> (grid: [[Int]], flashCount: Int) {
	var nextFlashes = Set<IntPoint>()
	var grid = grid
	let alreadyKnownFlashes = alreadyFlashed.union(flashes)
	for flash in flashes {
		var pointsToRaise = Set<IntPoint>()
		let x = flash.x
		let y = flash.y
		if (y > 0) {
			// Top
			pointsToRaise.insert(IntPoint(x: x, y: y - 1))
			// Top left
			if (x > 0) {
				pointsToRaise.insert(IntPoint(x: x - 1, y: y - 1))
			}

			// Top Right
			if (x < grid.count - 1) {
				pointsToRaise.insert(IntPoint(x: x + 1, y: y - 1))
			}
		} 
		
		// Left
		if (x > 0) {
			pointsToRaise.insert(IntPoint(x: x - 1, y: y))
		}
		
		if (y < grid.count - 1) {
			// Bottom
			pointsToRaise.insert(IntPoint(x: x, y: y + 1))

			// Bottom Left
			if (x > 0) {
				pointsToRaise.insert(IntPoint(x: x - 1, y: y + 1))
			}

			// Bottom right
			if (x < grid.count - 1) {
				pointsToRaise.insert(IntPoint(x: x + 1, y: y + 1))
			}
		}
		
		// Right
		if (x < grid.count - 1) {
			pointsToRaise.insert(IntPoint(x: x + 1, y: y))
		}

		for point in pointsToRaise {
			grid[point.y][point.x] += 1
			if (grid[point.y][point.x] > 9 && alreadyKnownFlashes.contains(point) == false) {
				nextFlashes.insert(point)
			}
		}
	}

	if nextFlashes.isEmpty == false {
		return processFlashes(nextFlashes, inGrid: grid, alreadyFlashed: alreadyKnownFlashes)
	} else {
		for point in alreadyKnownFlashes {
			grid[point.y][point.x] = 0
		}

		return (grid, alreadyKnownFlashes.count)
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
