#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

	func compute(lines: [String], index: Int = 0, forMostCommon: Bool) -> [String] {
		var ones = [String]()
		var zeros = [String]()
		for line in lines {
			if (line[index] == "0") {
				zeros.append(line)
			} else {
				ones.append(line)
			}
		}

		let toKeep: [String] = {
			if (forMostCommon == true) {
				return (ones.count >= zeros.count) ? ones : zeros
			} else {
				return (zeros.count <= ones.count) ? zeros : ones
			}
		}()

		let nextIndex = index + 1
		if (toKeep.count == 1) {
			return toKeep
		} else {
			return compute(lines: toKeep, index: nextIndex, forMostCommon: forMostCommon)
		}
	}

extension String {
    subscript(idx: Int) -> String {
        String(self[index(startIndex, offsetBy: idx)])
    }
}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)
	var lines = [String]()
	fileURL.processLineByLine { (line: String) in
		lines.append(line)
	}

	let oxygen = compute(lines: lines, forMostCommon: true).first!
	let co2 = compute(lines: lines, forMostCommon: false).first!

	let binaryIntOxygen = UInt(oxygen, radix: 2)!
	let binaryIntCO2 = UInt(co2, radix: 2)!

	print("LIFE SUPPORT \(binaryIntOxygen * binaryIntCO2)") 
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
