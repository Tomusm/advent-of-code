#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

do {
	guard (CommandLine.argc == 2) else {
		throw ScriptError.arguments
	}

	let inputPath = CommandLine.arguments[1]

	let fileURL = URL(fileURLWithPath: inputPath)

	fileURL.processLineByLine { (line: String) in
		let hexArray = line.map { String($0) }

		let packetBuilder = PacketBuilder()
		var packets = [Packet]()
		for hex in hexArray {
			let packet = packetBuilder.feedHex(hex)
			if let packet = packet {
				packets.append(packet)
			}
		}

		print("VERSION SUM \(packets.reduce(0) { $0 + $1.versionSum })")

		let packet = packets.first!
		print("RESOLVED \(packet.value)")
		
	}
} catch {
	print(error)
}

class PacketBuilder {

	private var version = -1
	private var typeID = -1
	private var remainingBitString = [String]()
	private var literalGroups = [String]()
	private var lengthID = -1
	private var length = -1

	private func reset(withRemainig: Bool) {
		self.version = -1
		self.typeID = -1
		self.lengthID = -1
		self.length = -1
		if (withRemainig == true) {
			self.remainingBitString.removeAll()
		}

		self.literalGroups.removeAll()
	}

	private func buildLiteralPacket() -> LiteralPacket {
		let literalValue = Int(self.literalGroups.joined(separator: ""), radix: 2)!
		let header = PacketHeader(version: self.version, typeID: self.typeID)
		return LiteralPacket(header: header, literal: literalValue)
	}

	func feedHex(_ hexString: String) -> Packet? {
		self.remainingBitString = self.remainingBitString + hexString.bitString().map { String($0) }

		while (true) {
			let count = self.remainingBitString.count
			let packet = self.addBinary()
			if let packet = packet {
				self.reset(withRemainig: true)
				return packet
			} else if (count == self.remainingBitString.count) {
				// No Progress
				break
			}
		}

		return nil
	}

	private func findSubpacketsForBinary(_ bitStrings: [String], stopsAt: Int? = nil) -> ([Packet], [String]) {
		self.remainingBitString = bitStrings

		var packets = [Packet]()
		while (true) {
			let count = self.remainingBitString.count
			let packet = self.addBinary()
			if let packet = packet {
				packets.append(packet)
				self.reset(withRemainig: false)
				if let stopsAt = stopsAt, packets.count == stopsAt {
					break
				}
			} else if (count == self.remainingBitString.count) {
				// No Progress
				break
			}
		}

		return (packets, self.remainingBitString)
	}

	private func addBinary() -> Packet? {
		let bitStrings = self.remainingBitString
		if (version == -1) {
			guard (self.remainingBitString.count >= 3) else {
				return nil
			}

			// 3 bits
			let threeBits = bitStrings[0..<3].joined(separator: "")
			self.version = Int(threeBits, radix: 2)!

			self.remainingBitString = Array(bitStrings[3...])
		} else if (self.typeID == -1) {
			// 3 bits
			guard (self.remainingBitString.count >= 3) else {
				return nil
			}

			let threeBits = bitStrings[0..<3].joined(separator: "")
			self.typeID = Int(threeBits, radix: 2)!
			self.remainingBitString = Array(bitStrings[3...])
		} else if (self.typeID == 4) {
			// Literal
			guard (bitStrings.count >= 5) else {
				return nil
			}

			// Discard first bit
			let indicator = bitStrings.first!
			let group = bitStrings[1..<5]
			literalGroups.append(contentsOf: group)
			self.remainingBitString = Array(bitStrings[5...])

			if (indicator == "0") {
				let literalPacket = self.buildLiteralPacket()
				return .literal(literalPacket)
			}
		} else {
			// Operator
			if (self.lengthID == -1) {
				guard (bitStrings.count >= 1) else {
					return nil
				}

				self.lengthID = Int(bitStrings.first!)!
				self.remainingBitString.removeFirst()
			} else if (self.lengthID == 0) {
				if (self.length == -1) {
					guard bitStrings.count >= 15 else {
						return nil
					}

					let fifteenBitString = bitStrings[0..<15].joined(separator: "")
					self.length = Int(fifteenBitString, radix: 2)!
					self.remainingBitString = Array(bitStrings[15...])
				} else {
					guard bitStrings.count >= self.length else {
						return nil
					}

					// We have the full length, we can build sub packets
					let subPacketBits = Array(bitStrings[0..<self.length])
					let subPacketBuilder = PacketBuilder()
					
					let subPacketsAndRemaining = subPacketBuilder.findSubpacketsForBinary(subPacketBits)
					let subPackets  = subPacketsAndRemaining.0
					self.remainingBitString = Array(bitStrings[self.length...])

					let header = PacketHeader(version: self.version, typeID: self.typeID)
					return .operator(OperatorPacket(header: header, subPackets: subPackets))
				}
			} else {
				// lenghtID = 1
				// Here self.length is the number of subPackets
				if (self.length == -1) {
					guard bitStrings.count >= 11 else {
						return nil
					}

					let fifteenBitString = bitStrings[0..<11].joined(separator: "")
					self.length = Int(fifteenBitString, radix: 2)!
					self.remainingBitString = Array(bitStrings[11...])
				} else {
					let subPacketBuilder = PacketBuilder()
					let subPacketsAndRemaining = subPacketBuilder.findSubpacketsForBinary(bitStrings, stopsAt: self.length)
					let subPackets = subPacketsAndRemaining.0
					guard subPackets.count == self.length else {
						return nil
					}

					self.remainingBitString = subPacketsAndRemaining.1
					let header = PacketHeader(version: self.version, typeID: self.typeID)
					return .operator(OperatorPacket(header: header, subPackets: Array(subPackets[0..<self.length])))
				}
			}
		}

		return nil
	}
}

struct PacketHeader {

	let version: Int // 3 bits
	let typeID: Int // 3 bits
}

enum Packet {
	case literal(LiteralPacket)
	case `operator`(OperatorPacket)

	var header: PacketHeader {
		switch self {
			case .literal(let packet): 
				return packet.header
			case .operator(let packet):
				return packet.header
		}
	}

	var packetItem: Any {
		switch self {
			case .literal(let packet): 
				return packet
			case .operator(let packet):
				return packet
		}
	}

	var value: Int {
		switch self {
			case .literal(let packet): 
				return packet.literal
			case .operator(let packet):
				return packet.resolvedValue
		}
	}

	var versionSum: Int {
		switch self {
			case .literal(let packet): 
				return packet.header.version
			case .operator(let packet):
				return packet.subPackets.reduce(0) { $0 + $1.versionSum } + packet.header.version
		}
	}
}

// ID = 4
struct LiteralPacket {

	let header: PacketHeader
	let literal: Int // Group of 5 bits, Indicator + 4 bits. Indicator = 0 shows that it's the last
}

struct OperatorPacket {
	
	let header: PacketHeader
	let subPackets: [Packet]


	var resolvedValue: Int {
		switch self.header.typeID {
			case 0:
				// sum
				return self.subPackets.reduce(0) { $0 + $1.value }
			case 1:
				// product
				return self.subPackets.reduce(1) { $0 * $1.value }
			case 2:
				// min
				return self.subPackets.sorted { $0.value < $1.value }.first!.value
			case 3:
				// max
				return self.subPackets.sorted { $0.value < $1.value }.last!.value
			case 5:
				// greater than
				return (self.subPackets[0].value > self.subPackets[1].value) ? 1 : 0
			case 6:
				// less than
				return (self.subPackets[0].value < self.subPackets[1].value) ? 1 : 0
			case 7:
				// equal to
				return (self.subPackets[0].value == self.subPackets[1].value) ? 1 : 0
			default: 
				break
		}
		
		return 0
	}
}

extension String {

	func bitString() -> String {
		var binaryString = String(Int(self, radix: 16)!, radix: 2)
		let modulo4 = binaryString.count % 4
		guard modulo4 != 0 else {
			return binaryString
		}

		for _ in 0..<(4-modulo4) {
			binaryString = "0\(binaryString)"
		}

		return binaryString
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
