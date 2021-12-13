#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)
	var map = [Cave: [Cave]]()
	fileURL.processLineByLine { (line: String) in
		let elements = line.components(separatedBy: "-").map { Cave($0) } 
		map[elements[0]] = (map[elements[0]] ?? []) + [elements[1]]
		map[elements[1]] = (map[elements[1]] ?? []) + [elements[0]]
	}

	let smallCaves = map.keys.filter { $0.isBig == false && $0 != Cave.start && $0 != Cave.end }
	var allPaths = Set<[Cave: [Int]]>()
	// BRUTE FOOOOOOORCE!
	for smallCave in smallCaves {
		allPaths.formUnion(findAllPathsFromStart(map: map, smallCaveVisitedTwice: smallCave))
	}
	
	print(allPaths.count)
} catch {
	print(error)
}

func findAllPathsFromStart(map: [Cave: [Cave]], smallCaveVisitedTwice: Cave) -> Set<[Cave: [Int]]> {
	let start = Cave.start
	let way = [start: [0]]
	return findAllPaths(from: start, jump: 1, way: way, map: map, smallCaveVisitedTwice: smallCaveVisitedTwice)
}

func findAllPaths(from cave: Cave, jump: Int, way: [Cave: [Int]], map: [Cave: [Cave]], smallCaveVisitedTwice: Cave) -> Set<[Cave: [Int]]> {
	var allPaths = Set<[Cave: [Int]]>()
	let paths = map[cave]
	for next in paths! {
		var currentPath = way

		guard next.isBig == true || currentPath[next] == nil || (next == smallCaveVisitedTwice && (currentPath[next]?.count ?? 0) <= 1) else {
			continue
		}

		currentPath[next] = (currentPath[next] ?? []) + [jump]
		let cameBackTooMuch = (currentPath[next]!.count > map[next]!.count) 
		if (next != Cave.end) && (cameBackTooMuch == false) {
			allPaths.formUnion(findAllPaths(from: next, jump: jump + 1, way: currentPath, map: map, smallCaveVisitedTwice: smallCaveVisitedTwice))
		} else if (cameBackTooMuch == false) {
			allPaths.insert(currentPath)
		}

	}

	return allPaths
}

struct Cave: Hashable {

	let name: String
	let isBig: Bool

	init(_ name: String) {
		self.isBig = (name.uppercased() == name)
		self.name = name
	}

	static let start = Cave("start")
	static let end = Cave("end")
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
