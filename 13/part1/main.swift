#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	var paper = Set<IntPoint>()
	var folds = [Fold]()
	var paperDone = false
	fileURL.processLineByLine { (line: String) in
		if (paperDone == false) {
			if (line.isEmpty == false) {
				let coordinate = line.components(separatedBy: ",").compactMap { Int($0) }
				paper.insert(IntPoint(x: coordinate[0], y: coordinate[1]))
			} else {
				paperDone = true
			}
		} else {
			let rawFold = line.replacingOccurrences(of: "fold along ", with: "").components(separatedBy: "=")
			let fold = Fold(axis: Axis(rawValue: rawFold[0])!, value: Int(rawFold[1])!)
			folds.append(fold)
		}
	}

	paper = fold(folds[0], onPaper: paper)

	print(paper.count)

} catch {
	print(error)
}

struct Fold {
	let axis: Axis
	let value: Int
}

enum Axis: String {
	case x
	case y
}

func fold(_ fold: Fold, onPaper paper: Set<IntPoint>) -> Set<IntPoint> {
	var foldedPaper = Set<IntPoint>()

	for point in paper {
		let valueToChange: Int = {
			switch fold.axis {
			case .x:
				return point.x
			case .y:
				return point.y
			}
		}()

		guard (valueToChange != fold.value) else {
			// Bye bye
			continue
		}

		if (valueToChange < fold.value) {
			foldedPaper.insert(point)
		} else {
			let diff = (valueToChange - fold.value)
			
			let newPoint: IntPoint = {
			switch fold.axis {
				case .x:
					return IntPoint(x: fold.value - diff, y: point.y)
				case .y:
					return IntPoint(x: point.x, y: fold.value - diff)
				}
			}()

			foldedPaper.insert(newPoint)
		}
	}

	return foldedPaper
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
