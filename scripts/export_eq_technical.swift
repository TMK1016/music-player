import Foundation

@main struct ExportEQTechnical {
    static func main() throws {
        let input = URL(fileURLWithPath: CommandLine.arguments[1]), output = URL(fileURLWithPath: CommandLine.arguments[2])
        var source = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [String: Any]
        var examples = source["examples"] as! [[String: Any]]
        for index in examples.indices {
            let gains = examples[index]["gains"] as! [Double], bass = examples[index]["bass"] as! Double
            let ambience = Ambience(rawValue: examples[index]["ambience"] as! String)!, mix = examples[index]["mix"] as! Double
            examples[index]["old_gain"] = -min(96, 3 + gains.filter { $0 > 0 }.reduce(0, +) + bass + (ambience == .off ? 0 : 6))
            examples[index]["new_gain"] = Double(EQHeadroom.gain(gains: gains, bass: bass, ambience: ambience, mix: mix))
            examples[index]["peak"] = EQHeadroom.peak(gains: gains, bass: bass)
            examples[index]["curve"] = (0...180).map { i in
                let frequency = 20 * pow(1000, Double(i)/180)
                return [frequency, EQHeadroom.response(gains: gains, bass: bass, at: frequency)]
            }
        }
        source["sample_rate"] = 44100; source["examples"] = examples
        try JSONSerialization.data(withJSONObject: source, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: output)
    }
}
