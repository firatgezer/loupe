import ArgumentParser

@main
struct Loupe: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "loupe",
        abstract: "Cut out subjects, read text and scan codes in images and PDFs.",
        discussion: "Everything runs on your Mac with Apple's Vision framework. Nothing is uploaded.",
        version: "0.1.0",
        subcommands: [CutoutCommand.self, TextCommand.self, CodesCommand.self]
    )
}
