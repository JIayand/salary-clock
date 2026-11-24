import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: generate-app-icon.swift <input.svg> <output.png>\n", stderr)
    exit(2)
}

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["rsvg-convert", "--width", "1024", "--height", "1024", input]

let pipe = Pipe()
process.standardOutput = pipe
try process.run()
let png = pipe.fileHandleForReading.readDataToEndOfFile()
process.waitUntilExit()

guard process.terminationStatus == 0, !png.isEmpty else {
    fputs("Failed to render SVG app icon. Install librsvg: brew install librsvg\n", stderr)
    exit(process.terminationStatus == 0 ? 1 : process.terminationStatus)
}
try png.write(to: URL(fileURLWithPath: output))
print("Rendered SVG app icon: \(output)")
