// This file guarantees original kbsd icon artwork at the native 1024px resolution.
import AppKit

let destination = CommandLine.arguments.dropFirst().first ?? "public/assets/images/app-icon.png"
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.075, green: 0.09, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 38, y: 38, width: 948, height: 948), xRadius: 212, yRadius: 212)
  .fill()
NSColor(calibratedRed: 0.21, green: 0.82, blue: 0.72, alpha: 1).setFill()
NSBezierPath(
  roundedRect: NSRect(x: 220, y: 216, width: 584, height: 610), xRadius: 142, yRadius: 142
).fill()
NSColor(calibratedRed: 0.39, green: 0.94, blue: 0.81, alpha: 1).setFill()
NSBezierPath(
  roundedRect: NSRect(x: 244, y: 284, width: 536, height: 518), xRadius: 126, yRadius: 126
).fill()
NSColor(calibratedRed: 0.075, green: 0.19, blue: 0.20, alpha: 1).setFill()
for (x, y, height) in [(352, 450, 158), (464, 394, 270), (576, 426, 206)] {
  NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 64, height: height), xRadius: 32, yRadius: 32)
    .fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
  to: URL(fileURLWithPath: destination))
