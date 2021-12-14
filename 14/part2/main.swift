#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	var polymer = [String]()
	var rules = [String: String]()
	fileURL.processLineByLine { (line: String) in
		if (polymer.isEmpty == true) {
			polymer = line.map { String($0) }
		} else if (line.isEmpty == false) {
			let components = line.components(separatedBy: " -> ")
			rules[components[0]] = components[1]
		} 
	}
	
	var pairs = [String: Int64]()
	for (index, letter) in polymer.enumerated() {
		if (index == 0) {
			continue
		}

		let pair = polymer[index-1]+letter
		pairs[pair] = (pairs[pair] ?? 0) + 1
	}

	for step in 1...40 {
		print("Step \(step)")
		pairs = performStep(pairs, rules: rules)
	}

	 var counts = [String: Int64]()
	 for (pair, amount) in pairs {
		let fistChar = String(pair.first!)
		let lastChar = String(pair.last!)
	 	counts[fistChar] = (counts[fistChar] ?? 0) + amount
		counts[lastChar] = (counts[lastChar] ?? 0) + amount
	 }

	counts[polymer.first!] = counts[polymer.first!]! + 1
	counts[polymer.last!] = counts[polymer.last!]! + 1

	let sortedCount = counts.values.sorted { $0 < $1 }
	let most = sortedCount.last! / 2
	let least = sortedCount.first! / 2
	print(most - least)
} catch {
	print(error)
}

func performStep(_ pairs: [String: Int64], rules: [String: String]) -> [String: Int64] {
	var updatedPairs = pairs

	for (pair, amount) in pairs {
		let pairWithFirstChar = String(pair.first!)+rules[pair]!
		let pairWithLastChar = rules[pair]!+String(pair.last!)
		updatedPairs[pairWithFirstChar] = (updatedPairs[pairWithFirstChar] ?? 0) + amount
		updatedPairs[pairWithLastChar] = (updatedPairs[pairWithLastChar] ?? 0) + amount
		updatedPairs[pair] = (updatedPairs[pair] ?? 0) - amount
	}

	return updatedPairs
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
