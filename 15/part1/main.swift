#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	var map = [[Int]]()
	fileURL.processLineByLine { (line: String) in
		map.append(line.map { String($0) }.compactMap { Int($0) })
	}

	var weightForPoint = [IntPoint: Int]()
	weightForPoint[IntPoint(x: 0, y: 0)] = 0
	var step: Int = 1

	var distanceFromNode = [IntPoint: Int]()
	distanceFromNode[IntPoint(x: 0, y: 0)] = 0
	var nodesToVisitNext = Set<IntPoint>([IntPoint(x: 0, y: 0)])
	let finalNode = IntPoint(x: map.count - 1, y: map.count - 1)
	while nodesToVisitNext.isEmpty == false {
		var newNodesToVisitNext = Set<IntPoint>()
		for currentNode in nodesToVisitNext {
			let currentPoint = currentNode
			let weight = distanceFromNode[currentNode] ?? Int.max

			if map.count > currentPoint.y + 1 {
				let addedWeight = weight + map[currentPoint.y + 1][currentPoint.x]
				let point = IntPoint(x: currentPoint.x, y: currentPoint.y + 1)
				if (addedWeight < distanceFromNode[point] ?? Int.max) {
					distanceFromNode[point] = addedWeight
					newNodesToVisitNext.insert(point)
				}
			}

			if map[currentPoint.y].count > currentPoint.x + 1 {
				let addedWeight = weight + map[currentPoint.y][currentPoint.x + 1]
				let point = IntPoint(x: currentPoint.x + 1, y: currentPoint.y)
				if (addedWeight < distanceFromNode[point] ?? Int.max) {
					distanceFromNode[point] = addedWeight
					newNodesToVisitNext.insert(point)
				}
			}

			if currentPoint.x - 1 > 0 {
				let addedWeight = weight + map[currentPoint.y][currentPoint.x - 1]
				let point = IntPoint(x: currentPoint.x - 1, y: currentPoint.y)
				if (addedWeight < distanceFromNode[point] ?? Int.max) {
					distanceFromNode[point] = addedWeight
					newNodesToVisitNext.insert(point)
				}
			}

			if currentPoint.y - 1 > 0 {
				let addedWeight = weight + map[currentPoint.y - 1][currentPoint.x]
				let point = IntPoint(x: currentPoint.x, y: currentPoint.y - 1)
				if (addedWeight < distanceFromNode[point] ?? Int.max) {
					distanceFromNode[point] = addedWeight
					newNodesToVisitNext.insert(point)
				}
			}
		}

		nodesToVisitNext = newNodesToVisitNext
		step += 1
	}

	print(distanceFromNode[finalNode]!)
} catch {
	print(error)
}

struct IntPoint: Hashable {
	let x: Int
	let y : Int
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
