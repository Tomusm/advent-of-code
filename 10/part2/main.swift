#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

enum ChunkState {
	case valid
	case invalid(BracketPair)
	case incomplete(Int)
}

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)
	var incompleteScores = [Int]()
	fileURL.processLineByLine { (line: String) in
		let chunk = line.map { String($0) }
		let state = processChunk(chunk)
		let incompleteScore = incompleteScore(fromState: state)
		if (incompleteScore != 0) {
			incompleteScores.append(incompleteScore)
		}
	}

	print(incompleteScores.sorted()[incompleteScores.count / 2])

} catch {
	print(error)
}

func syntaxErrorScore(fromState state: ChunkState) -> Int {
	switch state {
	case .invalid(let bracketPair):
		return bracketPair.syntaxErrorValue
	default:
		break
	}

	return 0
}

func incompleteScore(fromState state: ChunkState) -> Int {
	switch state {
	case .incomplete(let score):
		return score
	default:
		break
	}

	return 0
}

struct BracketPair {
	let start: String
	let end: String
	let syntaxErrorValue: Int
	let incompleteValue: Int

	static func bracketPair(startingWith: String) -> BracketPair {
		switch startingWith {
		case regularBracket.start:
			return regularBracket
		case squareBracket.start:
			return squareBracket
		case curlyBracket.start:
			return curlyBracket
		case triangleBracket.start:
			return triangleBracket
		default:
			fatalError()	
		}
	}

	static func bracketPair(endingWith: String) -> BracketPair {
		switch endingWith {
		case regularBracket.end:
			return regularBracket
		case squareBracket.end:
			return squareBracket
		case curlyBracket.end:
			return curlyBracket
		case triangleBracket.end:
			return triangleBracket
		default:
			fatalError()	
		}
	}

	static let regularBracket = BracketPair(start: "(", end: ")", syntaxErrorValue: 3, incompleteValue: 1)
	static let squareBracket = BracketPair(start: "[", end: "]", syntaxErrorValue: 57, incompleteValue: 2)
	static let curlyBracket = BracketPair(start: "{", end: "}", syntaxErrorValue: 1197, incompleteValue: 3)
	static let triangleBracket = BracketPair(start: "<", end: ">", syntaxErrorValue: 25137, incompleteValue: 4)

	static let all = [regularBracket, squareBracket, curlyBracket, triangleBracket]
}

func processChunk(_ chunk: [String]) -> ChunkState {
	let openingBrackets = Set(BracketPair.all.map { $0.start })

	var openedBrackets = [BracketPair]()
	for bracket in chunk {
		if (openingBrackets.contains(bracket)) {
			openedBrackets.append(BracketPair.bracketPair(startingWith: bracket))
		} else if (openedBrackets.last!.end == bracket) {
			openedBrackets.removeLast()
		} else {
			return .invalid(BracketPair.bracketPair(endingWith: bracket))
		}
	}

	if (openedBrackets.isEmpty == true) {
		return .valid
	} else {
		var totalScore = 0
		for openedBracket in openedBrackets.reversed() {
			totalScore *= 5
			totalScore += openedBracket.incompleteValue
		}

		return .incomplete(totalScore)
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
