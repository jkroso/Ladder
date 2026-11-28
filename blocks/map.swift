// Does the two things that Ladder's maps need from MapKit, which is part of
// macOS. macOS only offers MapKit to Swift and Objective-C, so this is a
// program of its own, and Ladder runs it. See map.jl.
//
// It makes a picture of the map round a point:
//
//     map 15 720 280 site.png -37.7681,144.9426
//     map --dark 15 720 280 site.png -37.7681,144.9426
//
// The arguments are the zoom, how wide and how tall the picture is in px, the
// PNG file to write, and the latitude and the longitude in the middle of the
// picture. The zoom is the one that maps on the web use: each step shows half
// as much from side to side, and 15 shows a few streets. The file has two
// pixels to the px, so the picture is sharp on a Retina screen. With --dark,
// the map has the colours of a dark page. The picture has no pin: Ladder
// draws the pin over it.
//
// The picture is a rectangle of the map of the world as maps on the web draw
// it, which is 256 px wide at zoom 0 and twice as wide at each step. So map.jl
// can work out which latitude and longitude is at each point of the picture.
//
// And it finds a place:
//
//     map --find "8 Wattle Street, Brunswick VIC 3056"
//     map --find -37.7701,144.9610
//
// It prints one line: the latitude, the longitude and the address that Apple
// has for the place, with a tab between each two. For a latitude and a
// longitude, the address is the one that Apple has for that point, and it's
// empty when Apple has none.
//
// If it can't do what it's asked, it prints "error: " and why on stderr. It
// exits with 2 when Apple finds no such place, and with 1 for anything else,
// like no network.
//
// Apple finds an address from its words, and that needs the network, as the
// first picture of a part of the map does. The program never asks where the
// Mac is, so macOS asks the person for nothing.

import AppKit
import Foundation
import MapKit

@main
struct MapPicture {
  /// How many pixels of the file go to a px of the picture
  static let scale = 2.0
  /// How many seconds Apple gets to answer before the program gives up
  static let patience = 30.0

  static func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
  static func fail(_ why: String, code: Int32 = 1) -> Never { say("error: " + why); exit(code) }

  /// The latitude and the longitude that `place` holds, like "-37.7701, 144.9610", or nil when it's an address
  static func coordinate(_ place: String) -> CLLocationCoordinate2D? {
    let parts = place.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    // A number here has only digits, a point and a sign, as map.jl has it
    guard parts.count == 2, parts.allSatisfy({ $0.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" } }),
          let lat = Double(parts[0]), let lon = Double(parts[1]), abs(lat) <= 90, abs(lon) <= 180 else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  /// An address on one line
  static func oneLine(_ address: String?) -> String {
    (address ?? "").split(whereSeparator: { $0.isNewline || $0 == "\t" })
      .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
  }

  /// True when MapKit says that it found nothing. Any other error is the network.
  static func nothingFound(_ error: Error) -> Bool {
    let e = error as NSError
    return e.domain == MKError.errorDomain && e.code == Int(MKError.placemarkNotFound.rawValue)
  }

  /// Print where `place` is, and the address that Apple has for it
  static func find(_ place: String) async -> Never {
    guard !place.isEmpty else { fail("The place is empty", code: 2) }
    var at: CLLocationCoordinate2D
    var address = ""
    if let given = coordinate(place) {
      at = given
      guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: given.latitude, longitude: given.longitude)) else {
        fail("Apple's maps can't read this latitude and longitude")
      }
      do {
        address = oneLine(try await request.mapItems.first?.address?.fullAddress)
      } catch {
        // A point with no address, like one at sea, is found all the same
        if !nothingFound(error) { fail(error.localizedDescription) }
      }
    } else {
      guard let request = MKGeocodingRequest(addressString: place) else { fail("Apple's maps can't read this address", code: 2) }
      let items: [MKMapItem]
      do { items = try await request.mapItems } catch {
        fail(nothingFound(error) ? "Apple's maps found no such place" : error.localizedDescription, code: nothingFound(error) ? 2 : 1)
      }
      guard let item = items.first else { fail("Apple's maps found no such place", code: 2) }
      at = item.location.coordinate
      address = oneLine(item.address?.fullAddress)
    }
    print(String(format: "%.6f\t%.6f\t", at.latitude, at.longitude) + address)
    exit(0)
  }

  static func main() async {
    var args = Array(CommandLine.arguments.dropFirst())
    // Apple gets so long to answer. A Mac with no network can wait much longer than that.
    Task.detached {
      try? await Task.sleep(nanoseconds: UInt64(patience * 1e9))
      fail("Apple's maps didn't answer in \(Int(patience)) seconds")
    }
    if args.first == "--find" {
      guard args.count == 2 else { fail("Say which place to find, like this: map --find \"8 Wattle Street, Brunswick\"") }
      await find(args[1].trimmingCharacters(in: .whitespacesAndNewlines))
    }
    let dark = args.first == "--dark"
    if dark { args.removeFirst() }
    guard args.count == 5, let zoom = Double(args[0]), let wide = Double(args[1]), let tall = Double(args[2]),
          wide >= 1, tall >= 1, let middle = coordinate(args[4]) else {
      fail("Say the zoom, the size, the file and the middle of the map, like this: map 15 720 280 site.png -37.7681,144.9426")
    }
    let out = URL(fileURLWithPath: args[3])

    // MapKit's own map of the world is the one that maps on the web draw, 2^28 of its points wide. A map on the web
    // is 256 px wide at zoom 0 and twice as wide at each step, so a px is 2^(20 - zoom) of MapKit's points.
    let world = MKMapSize.world
    var per = pow(2, 20 - min(max(zoom, 1), 20))
    // MapKit shows no more than half the width of the world, so a picture that asks for more shows a little less
    per = min(per, world.width / 2 / wide, world.height / 2 / tall)
    let at = MKMapPoint(middle)
    // The map of the world has a top and a bottom, and the picture stays between them
    let top = min(max(at.y - tall * per / 2, 0), world.height - tall * per)
    let options = MKMapSnapshotter.Options()
    options.mapRect = MKMapRect(x: at.x - wide * per / 2, y: top, width: wide * per, height: tall * per)
    options.size = NSSize(width: wide, height: tall)
    options.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
    let shot: MKMapSnapshotter.Snapshot
    do { shot = try await MKMapSnapshotter(options: options).start() } catch { fail(error.localizedDescription) }

    // The map is drawn into a picture of our own, so the file has `scale` pixels to the px on any Mac
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(wide * scale), pixelsHigh: Int(tall * scale),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fail("The Mac couldn't make the picture") }
    // The picture's size in px is set before its context is made, so what's drawn is `scale` times as big in pixels
    bitmap.size = NSSize(width: wide, height: tall)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fail("The Mac couldn't make the picture") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    shot.image.draw(in: NSRect(x: 0, y: 0, width: wide, height: tall))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fail("The Mac couldn't make the picture") }
    do { try png.write(to: out, options: .atomic) } catch { fail("The Mac couldn't write \(out.lastPathComponent)") }
    exit(0)
  }
}
