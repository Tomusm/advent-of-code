#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

enum Direction: CaseIterable {
	case up
	case down
	case left
	case right
}

struct IntPoint: Hashable {
	let x: Int
	let y: Int
}

class HeightPoint {

	let value: Int
	var lowestInDirection = Set<Direction>()
	let position: IntPoint

	init(value: Int, position: IntPoint, lowestInDirection: Set<Direction>) {
		self.value = value
		self.position = position
		self.lowestInDirection = lowestInDirection
	}

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

	var riskLevel = 0
	let fileURL = URL(fileURLWithPath: inputPath)
	var bassinMap = [[HeightPoint]]()
	var lowPoints = [HeightPoint]()
	var lineIndex = 0
	fileURL.processLineByLine { (line: String) in
		let values = line.map { String($0) }.compactMap { Int($0) }

		var currentLine = [HeightPoint]()
		for (index, value) in values.enumerated() {
			var lowest = Set<Direction>()
			if (bassinMap.isEmpty == true) {
				// First line case
				lowest.insert(.up)
			} else {
				if (value < bassinMap[lineIndex - 1][index].value) {
					lowest.insert(.up)
				} else {
					bassinMap[lineIndex - 1][index].lowestInDirection.insert(.down)
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

			currentLine.append(HeightPoint(value: value, position: IntPoint(x: index, y: lineIndex), lowestInDirection: lowest))
		}

		if (bassinMap.isEmpty == false) {
			for heightPoint in bassinMap[bassinMap.count - 1] {
				if (heightPoint.verify() == true) {
					riskLevel += 1 + heightPoint.value
					lowPoints.append(heightPoint)
				}
			}
		}

		bassinMap.append(currentLine)
		lineIndex += 1
	}

	for heightPoint in bassinMap[bassinMap.count - 1] {
		heightPoint.lowestInDirection.insert(.down)
		if (heightPoint.verify() == true) {
			riskLevel += 1 + heightPoint.value
			lowPoints.append(heightPoint)
		}
	}

	let result = computeResult(forLowestPoints: lowPoints, onMap: bassinMap)
	print(result)

} catch {
	print("\(error)")
}

func computeResult(forLowestPoints lowestPoints: [HeightPoint], onMap map: [[HeightPoint]]) -> Int {
	var bassinSizes = [Int]()

	for point in lowestPoints {
		let bassin = findBassin(forLowestPoint:point, onMap: map)
		bassinSizes.append(bassin.bassin.count)
	}

	bassinSizes.sort { $0 > $1 }
	return bassinSizes[0..<3].reduce(1) { $0 * $1 }
}

func findBassin(forLowestPoint point: HeightPoint, onMap map: [[HeightPoint]], checkedPositions: Set<IntPoint> = Set<IntPoint>()) -> (bassin: [HeightPoint], checkedPositions: Set<IntPoint>) {
	guard (point.value != 9) else {
		return ([], checkedPositions)
	}
	var checkedPositions = checkedPositions
	var bassin = [point]
	checkedPositions.insert(point.position)
	var pointsToCheck = [HeightPoint]()
	
	if (point.lowestInDirection.contains(.up)) {
		let position = IntPoint(x: point.position.x, y: point.position.y - 1)
		if (position.y >= 0 && checkedPositions.contains(position) == false) {
			pointsToCheck.append(map[position.y][position.x])
		}
	}

	if (point.lowestInDirection.contains(.down)) {
		let position = IntPoint(x: point.position.x, y: point.position.y + 1)
		if (position.y < map.count && checkedPositions.contains(position) == false) {
			pointsToCheck.append(map[position.y][position.x])
		}
	}

	if (point.lowestInDirection.contains(.left)) {
		let position = IntPoint(x: point.position.x - 1, y: point.position.y)
		if (position.x >= 0 && checkedPositions.contains(position) == false) {
			pointsToCheck.append(map[position.y][position.x])
		}
	}

	if (point.lowestInDirection.contains(.right)) {
		let position = IntPoint(x: point.position.x + 1, y: point.position.y)
		if (position.x < map[position.y].count && checkedPositions.contains(position) == false) {
			pointsToCheck.append(map[position.y][position.x])
		}
	}

	checkedPositions.formUnion(pointsToCheck.map { $0.position })

	for pointToCheck in pointsToCheck {
		let child = findBassin(forLowestPoint: pointToCheck, onMap: map, checkedPositions: checkedPositions)
		bassin.append(contentsOf: child.bassin)
		checkedPositions.formUnion(child.checkedPositions)
	}

	return (bassin, checkedPositions)
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
