// Writes down what's said in a sound file, or in the sound of a video file,
// with the speech recognition that's part of macOS 26 and later. macOS only
// offers it to Swift, so this is a program of its own, and Ladder runs it. See
// transcribe.jl.
//
//     transcribe memo.m4a
//     transcribe --times walk.mov
//
// It prints the text, with an empty line between two parts that have a pause
// between them. With --times, it prints each phrase on a line of its own: the
// second of the file where the phrase starts, the second where it ends, and its
// words, with a tab between each two. While it works, it prints lines on stderr that say how far it
// has got: "downloading" while macOS fetches what it needs for the language,
// and "done 0.42" when it has gone through 42% of the file. If it can't
// transcribe the file, it prints "error: " and why on stderr, and exits with 1.
//
// The sound stays on the Mac. macOS doesn't ask the person first, as it does
// for the speech recognition that sends sound to Apple.

import AVFoundation
import Foundation
import Speech

@main
struct Transcribe {
  /// How many seconds without words start a new paragraph
  static let pause = 2.0

  static func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
  static func fail(_ why: String) -> Never { say("error: " + why); exit(1) }

  static func main() async {
    let args = CommandLine.arguments
    let times = args.count == 3 && args[1] == "--times"
    guard args.count == 2 || times else { fail("Say which sound file to transcribe, like this: transcribe memo.m4a") }
    guard SpeechTranscriber.isAvailable else { fail("This Mac can't turn speech into text") }
    let url = URL(fileURLWithPath: args[args.count - 1])
    let file: AVAudioFile
    do { file = try AVAudioFile(forReading: url) } catch { fail("\(url.lastPathComponent) has no sound that macOS can read") }
    let seconds = Double(file.length) / file.processingFormat.sampleRate
    // The language that the Mac is set to, or the nearest one that macOS can transcribe
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
      fail("macOS can't turn speech in \(Locale.current.identifier) into text")
    }
    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        say("downloading")
        try await request.downloadAndInstall()
      }
    } catch { fail("macOS couldn't get what it needs to transcribe \(locale.identifier): \(error.localizedDescription)") }
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    // The results come while the analyzer reads the file, a phrase at a time
    let words = Task { () throws -> String in
      var text = ""
      var end = 0.0
      for try await result in transcriber.results {
        let phrase = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty && times {
          let words = phrase.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
          text += String(format: "%.2f\t%.2f\t", result.range.start.seconds, result.range.end.seconds) + words + "\n"
        } else if !phrase.isEmpty {
          text += text.isEmpty ? "" : result.range.start.seconds - end >= pause ? "\n\n" : " "
          text += phrase
        }
        end = result.range.end.seconds
        if seconds > 0 { say("done \(min(1, end / seconds))") }
      }
      return text
    }
    do {
      if let last = try await analyzer.analyzeSequence(from: file) {
        try await analyzer.finalizeAndFinish(through: last)
      } else {
        await analyzer.cancelAndFinishNow()
      }
      print(try await words.value)
    } catch { fail(error.localizedDescription) }
  }
}
