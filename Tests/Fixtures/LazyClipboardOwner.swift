import AppKit
// Dedicated synthetic owner process: avoids same-process AppKit/Carbon synchronization
// materializing promises before the receiver inspects the global pasteboard.
final class Provider: NSObject, NSPasteboardItemDataProvider {
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        print("REQUESTED", Date().timeIntervalSince1970); fflush(stdout)
        if CommandLine.arguments.count > 2, let delay = Double(CommandLine.arguments[2]) { Thread.sleep(forTimeInterval: delay) }
        item.setString("synthetic lazy content", forType: type)
    }
}
let board = NSPasteboard(name: .init(CommandLine.arguments[1]))
let provider = Provider(); let item = NSPasteboardItem()
board.clearContents()
if CommandLine.arguments.dropFirst(2).first == "rich" {
    item.setString("original é👩🏽‍💻", forType: .string)
    item.setData(Data("{\\rtf1 rich}".utf8), forType: .rtf)
    let image = NSPasteboardItem()
    image.setData(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!, forType: .png)
    board.writeObjects([item, image])
} else {
    item.setDataProvider(provider, forTypes: [.string]); board.writeObjects([item])
}
print("READY"); fflush(stdout)
RunLoop.main.run()
