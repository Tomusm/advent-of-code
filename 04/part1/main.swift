#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

struct NumberTile {
	let line: Int
	let column: Int

	var marked: Bool = false
}

class Board {
	var lines: [Int: NumberTile]

	var markedLines: [Int]
	var markedColumns: [Int]

	let winingCondition: Int

	init(lines: [[Int]]) {
		var markedColumns = [Int]()
		var markedLines = [Int]()
		// Shortcut: bingo is a square
		for _ in 0..<lines.count {
			markedColumns.append(0)
			markedLines.append(0)
		}

		var lineDict = [Int: NumberTile]()
		for (lineNumber, line) in lines.enumerated() {
			for (columnNumber, number) in line.enumerated() {
				lineDict[number] = NumberTile(line: lineNumber, column: columnNumber)
			}
		}

		self.lines = lineDict
		self.markedColumns = markedColumns
		self.markedLines = markedLines
		self.winingCondition = lines.count
	}

	/// Returns true if Bingo
	func mark(_ number: Int) -> Bool {
		guard var numberTile = self.lines[number] else {
			return false
		}

		numberTile.marked = true
		self.lines[number] = numberTile

		var markedLine = self.markedLines[numberTile.line]
		var markedColumn = self.markedColumns[numberTile.column]

		markedLine += 1
		markedColumn += 1

		self.markedLines[numberTile.line] = markedLine
		self.markedColumns[numberTile.column] = markedColumn

		if (markedLine == self.winingCondition) {
			// WIN
			return true
		} else if (markedColumn == self.winingCondition) {
			// WIN
			return true
		} else {
			return false
		}

	}

	func sumOfUnmarked() -> Int {
		var sum = 0
		for (number, tile) in self.lines {
			guard (tile.marked == false) else {
				continue
			}

			sum += number
		}

		return sum
	}
}


class BoardBuilder {
	var lines: [[Int]] = [[Int]]()

	func reset() {
		self.lines = [[Int]]()
	}

	func addLine(line: [Int]) {
		self.lines.append(line)
	}

	func build() -> Board {
		return Board(lines: self.lines)
	}
}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	var drawnNumbers = [Int]()

	var boards = [Board]()

	let boardBuilder = BoardBuilder()

	let fileURL = URL(fileURLWithPath: inputPath)
	fileURL.processLineByLine { (line: String) in
		if (drawnNumbers.isEmpty == true) {
			drawnNumbers = line.components(separatedBy: ",").compactMap { Int($0) }
		} else {
			let numbers = line.components(separatedBy: " ").compactMap { Int($0) }
			if (numbers.isEmpty == false) {
				boardBuilder.addLine(line: numbers)
			} else {
				boards.append(boardBuilder.build())
				boardBuilder.reset()
			}
		}
	}

	var won = false
	for drawnNumber in drawnNumbers {
		for board in boards {
			if (board.mark(drawnNumber) == true) {
				won = true
				let sum = board.sumOfUnmarked()
				let result = (sum * drawnNumber)
				print("WINNING: result \(result)")
				break
			}
			
			guard (won == false) else {
				break
			}
		}
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
