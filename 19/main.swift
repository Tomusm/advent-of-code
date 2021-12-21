#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard CommandLine.argc == 2 else { throw ScriptError.arguments }

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	let scannerReports = extractReports(from: fileURL)

	// Find common points by comparing diffs between points
	let diffReports = buildDiffReport(fromScannerReports: scannerReports)
	let correspondances = analyzeDiffReports(diffReports, scannerReports: scannerReports)

	// Figure out mapping between scanner reports
	var mappings = [Mapping]()
	for correspondance in correspondances {
		let mapping = resolveCorrespondance(correspondance, scannerReports: scannerReports)
		mappings.append(mapping)
	}

	// Figuring out the paths to 0
	var paths = [Int: [Int]]()
	for (index, _) in scannerReports.enumerated() {
		let directPaths = mappings.filter { $0.otherIndex == index }.map { $0.referenceIndex }  
		paths[index] = directPaths
	}

	let mappedSteps = findDestinationsTo(goal: 0, fromPaths: paths)

	var scannerPoints = Set<IntPoint>([IntPoint(x: 0, y: 0, z: 0)])
	var map = Set<IntPoint>(scannerReports[0])

	// Resolve all points relative to 0
	for (index, steps) in mappedSteps {
		print("Resolving \(index)")
		var points = Set<IntPoint>(scannerReports[index])
		var scannerPoint = IntPoint(x: 0, y: 0, z: 0)
		var currentReference = index
		for step in steps {
			let mapping = mappings.first { $0.otherIndex == currentReference && $0.referenceIndex == step }
			var convertedPoints = Set<IntPoint>()
			for point in points {
				let convertedPoint = mapPoint(point, forMapping: mapping!)	
				convertedPoints.insert(convertedPoint)
			}

			scannerPoint = mapPoint(scannerPoint, forMapping: mapping!)

			points = convertedPoints
			currentReference = mapping!.referenceIndex
		}

		map.formUnion(points)
		scannerPoints.insert(scannerPoint)
	}	

	// Part 1
	print("Beacon count: \(map.count)")

	var biggestDistance = 0
	for scannerPoint1 in scannerPoints {
		for scannerPoint2 in scannerPoints {
			guard (scannerPoint1 != scannerPoint2) else {
				continue
			}

			let distance = abs((scannerPoint1.x - scannerPoint2.x)) + abs(scannerPoint1.y - scannerPoint2.y) + abs(scannerPoint1.z - scannerPoint2.z)
			if distance > biggestDistance {
				biggestDistance = distance
			}
		}
	}

	// Part 2
	print("Biggest distance \(biggestDistance)")

} catch { print(error) }

func findDestinationsTo(goal: Int, fromPaths paths: [Int: [Int]]) -> [Int: [Int]] {

	var mappedSteps = [Int: [Int]]()
	for (origin, directDestinations) in paths {
		guard (origin != goal) else {
			continue
		}

		if (directDestinations.contains(goal)) {
			mappedSteps[origin] = [goal]
		} else {
			for directDestination in directDestinations {
				if (paths[directDestination]!.contains(goal)) {
					mappedSteps[origin] = [directDestination, goal]
				}
			}
		}
	}

	while mappedSteps.count < paths.count - 1 {
		for (origin, directDestinations) in paths {
			guard (origin != goal), mappedSteps[origin] == nil else {
				continue
			}

			for directDestination in directDestinations {
				if (mappedSteps[directDestination] ?? []).contains(goal) {
					mappedSteps[origin] = [directDestination] + mappedSteps[directDestination]!
					break
				}
			}
		}
	}

	return mappedSteps
}

func mapPoint(_ point: IntPoint, forMapping mapping: Mapping) -> IntPoint {
	let mappedX = (mapping.xMapping.1 ? point[keyPath: mapping.xMapping.0.keyPath] * -1 : point[keyPath: mapping.xMapping.0.keyPath]) + mapping.xMapping.2
	let mappedY = (mapping.yMapping.1 ? point[keyPath: mapping.yMapping.0.keyPath] * -1 : point[keyPath: mapping.yMapping.0.keyPath]) + mapping.yMapping.2
	let mappedZ = (mapping.zMapping.1 ? point[keyPath: mapping.zMapping.0.keyPath] * -1 : point[keyPath: mapping.zMapping.0.keyPath]) + mapping.zMapping.2

	return IntPoint(x: mappedX, y: mappedY, z: mappedZ)
}

func extractReports(from fileURL: URL) -> [[IntPoint]] {
	var scannerReports = [[IntPoint]]()

	var currentReport = [IntPoint]()
	fileURL.processLineByLine { (line: String) in
		guard line.starts(with: "--- scanner") == false else { return }

		if line.isEmpty {
			if currentReport.isEmpty == false {
				scannerReports.append(currentReport)
				currentReport.removeAll()
			}
		} else {
			let coordinates = line.components(separatedBy: ",").compactMap { Int($0) }

			currentReport.append(IntPoint(x: coordinates[0], y: coordinates[1], z: coordinates[2]))
		}
	}

	scannerReports.append(currentReport)

	return scannerReports
}

func buildDiffReport(fromScannerReports scannerReports: [[IntPoint]]) -> [DiffReport] {

	var diffPerReport = [DiffReport]()
	for (scannerIndex, report) in scannerReports.enumerated() {
		var diffList = Set<Diff>()
		for (index1, point1) in report.enumerated() {
			for (index2, point2) in report.enumerated() {
				guard index1 != index2 else { continue }

				let diffX = abs(max(point1.x, point2.x) - min(point2.x, point1.x))
				let diffY = abs(max(point1.y, point2.y) - min(point2.y, point1.y))
				let diffZ = abs(max(point1.z, point2.z) - min(point2.z, point1.z))
				let diff = Diff(baconIndex: (index1, index2), diffX: diffX, diffY: diffY, diffZ: diffZ)

				diffList.insert(diff)
			}
		}

		let report = DiffReport(scannerIndex: scannerIndex, report: diffList)
		diffPerReport.append(report)
	}

	return diffPerReport
}

func analyzeDiffReports(_ diffReports: [DiffReport], scannerReports: [[IntPoint]])
	-> [Correspondance]
{
	var correspondances = [Correspondance]()
	for diffReport1 in diffReports {
		for diffReport2 in diffReports {
			guard (diffReport1.scannerIndex != diffReport2.scannerIndex) else {
				continue
			}

			let commonDiffs = diffReport1.report.intersection(diffReport2.report)
			// We know how many diffs are in common
			let commonCount = Set(commonDiffs.map { $0.baconIndexes.map { $0 } }.joined()).count

			// Two items per diff
			if commonCount >= 6 {

				var diff1Dict = [Diff: Set<Int>]()
				diffReport1.report.filter { commonDiffs.contains($0) }.forEach {
					diff1Dict[$0] = $0.baconIndexes
				}

				var diff2Dict = [Diff: Set<Int>]()
				diffReport2.report.filter { commonDiffs.contains($0) }.forEach {
					diff2Dict[$0] = $0.baconIndexes
				}

				var correspondanceTable1 = [Int: Set<Int>]()
				for (key, value) in diff1Dict {
					value.forEach {
						if correspondanceTable1[$0] == nil {
							correspondanceTable1[$0] = diff2Dict[key]
						} else if correspondanceTable1[$0]!.count > 1 {
							correspondanceTable1[$0] = correspondanceTable1[$0]?.intersection(diff2Dict[key]!)
						}
					}

				}

				var correspondanceTable2 = [Int: Set<Int>]()
				for (key, value) in diff2Dict {
					value.forEach {
						if correspondanceTable2[$0] == nil {
							correspondanceTable2[$0] = diff1Dict[key]
						} else if correspondanceTable2[$0]!.count > 1 {
							correspondanceTable2[$0] = correspondanceTable2[$0]?.intersection(diff1Dict[key]!)
						}
					}
				}

				// 1, 2
				let values1 = correspondanceTable1.map { ($0.key, $0.value.first!) }
				correspondances.append(
					Correspondance(
						firstIndex: diffReport1.scannerIndex, secondIndex: diffReport2.scannerIndex,
						table: values1))

				let values2 = correspondanceTable2.map { ($0.key, $0.value.first!) }
				correspondances.append(
					Correspondance(
						firstIndex: diffReport2.scannerIndex, secondIndex: diffReport1.scannerIndex,
						table: values2))
			}
		}
	}

	return correspondances
}

func resolveCorrespondance(_ correspondance: Correspondance, scannerReports: [[IntPoint]]) -> Mapping {
	let scannerReport1 = scannerReports[correspondance.firstIndex]
	let scannerReport2 = scannerReports[correspondance.secondIndex]

	let point1A = scannerReport1[correspondance.table[0].0]
	let point1B = scannerReport1[correspondance.table[1].0]

	let point2A = scannerReport2[correspondance.table[0].1]
	let point2B = scannerReport2[correspondance.table[1].1]

	let xMapping = figureOutDirection(
		.x, point1A: point1A, point1B: point1B, point2A: point2A, point2B: point2B)

	let yMapping = figureOutDirection(
		.y, point1A: point1A, point1B: point1B, point2A: point2A, point2B: point2B)

	let zMapping = figureOutDirection(
		.z, point1A: point1A, point1B: point1B, point2A: point2A, point2B: point2B)

 	return Mapping(referenceIndex: correspondance.firstIndex, otherIndex: correspondance.secondIndex, xMapping: xMapping, yMapping: yMapping, zMapping: zMapping)
}

/// Returns matching (Cardinal point, opposed or not, diff)
func figureOutDirection(_ cardinal: Cardinal, point1A: IntPoint, point1B: IntPoint, point2A: IntPoint, point2B: IntPoint) -> (Cardinal, Bool, Int) {
	for cardinal2 in Cardinal.allCases {
		for opposite in [false, true] {
			let resolved = figureOutDirection(
				cardinal, cardinal2: cardinal2, opposite: opposite, point1A: point1A, point1B: point1B, point2A: point2A,
				point2B: point2B)
			if let resolved = resolved {
				return (resolved.0, opposite, resolved.1)
			}
		}
	}

	print("\(point1A) \(point1B)")
	print("\(point2A), \(point2B)")

	print("CANNOT FIND SOLUTION")
	fatalError("Should have resolved")
}

func figureOutDirection(
	_ cardinal1: Cardinal, cardinal2: Cardinal, opposite: Bool, point1A: IntPoint, point1B: IntPoint,
	point2A: IntPoint, point2B: IntPoint
) -> (Cardinal, Int)? {
	let point2AResolved = opposite ? point2A[keyPath: cardinal2.keyPath] * -1 : point2A[keyPath: cardinal2.keyPath]
	let point2BResolved = opposite ? point2B[keyPath: cardinal2.keyPath] * -1 : point2B[keyPath: cardinal2.keyPath]
	let diff1 = point1A[keyPath: cardinal1.keyPath] - point1B[keyPath: cardinal1.keyPath]
	let diff2 = point2AResolved - point2BResolved
//	print("\(cardinal1) diff \(diff1), \(diff2) \(opposite)")

	if diff1 == diff2 {
//		print("Ref point \(point1A[keyPath: cardinal1.keyPath]), other: \(point2AResolved)")
		let diff = point1A[keyPath: cardinal1.keyPath] - point2AResolved 
		return (cardinal2, diff)
	} else {
		return nil
	}
}

enum Cardinal: CaseIterable {
	case x
	case y
	case z

	var keyPath: KeyPath<IntPoint, Int> {
		switch self {
		case .x:
			return \.x
		case .y:
			return \.y
		case .z:
			return \.z
		}
	}
}

struct Mapping {

	let referenceIndex: Int
	let otherIndex: Int

	// Carinal, opposed (*-1 if true), diff
	var xMapping: (Cardinal, Bool, Int)
	var yMapping: (Cardinal, Bool, Int)
	var zMapping: (Cardinal, Bool, Int)
}

struct Correspondance {

	let firstIndex: Int
	let secondIndex: Int
	let table: [(Int, Int)]
}

struct DiffReport: Hashable {
	let scannerIndex: Int
	let report: Set<Diff>

	func hash(into hasher: inout Hasher) { hasher.combine(self.report) }
}

struct Diff: Hashable {
	let baconIndexes: Set<Int>
	let diffX: Int
	let diffY: Int
	let diffZ: Int
	private let diffSet: Set<Int>

	init(baconIndex: (Int, Int), diffX: Int, diffY: Int, diffZ: Int) {
		self.diffX = diffX
		self.diffY = diffY
		self.diffZ = diffZ
		self.baconIndexes = Set<Int>([baconIndex.0, baconIndex.1])
		self.diffSet = Set<Int>([self.diffX, self.diffY, self.diffZ])
	}

	func hash(into hasher: inout Hasher) { hasher.combine(self.diffSet) }

	static func == (lhs: Diff, rhs: Diff) -> Bool { return lhs.diffSet == rhs.diffSet }
}

struct IntPoint: Hashable {
	let x: Int
	let y: Int
	let z: Int
}

enum ScriptError: Error { case arguments }

extension URL {

	func processLineByLine(processLine: @escaping (_ line: String) -> Void) {

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

		while bytesRead > 0 {
			guard let linePointer = lineByteArrayPointer else { break }

			/// Note: this translates the sequence of bytes to a string
			/// using the UTF-8 encoding for interpreting byte sequences.
			var lineString = String.init(cString: linePointer)

			/// `lineString` initially includes the newline character, if one was found.
			if lineString.last?.isNewline == true { lineString = String(lineString.dropLast()) }

			/// Process this single line of text.
			processLine(lineString)

			/// Update number of bytes read and the pointers for the next iteration.
			bytesRead = nextLine()
		}
	}

}
