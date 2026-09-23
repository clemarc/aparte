import AppKit
// Dedicated synthetic owner process: avoids same-process AppKit/Carbon synchronization
// materializing promises before the receiver inspects the global pasteboard.
final class Provider: NSObject, NSPasteboardItemDataProvider {
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        print("REQUESTED", Date().timeIntervalSince1970); fflush(stdout)
        item.setString("synthetic lazy content", forType: type)
    }
}
let board = NSPasteboard(name: .init(CommandLine.arguments[1]))
let provider = Provider(); let item = NSPasteboardItem()
item.setDataProvider(provider, forTypes: [.string]); board.clearContents(); board.writeObjects([item])
print("READY"); fflush(stdout)
RunLoop.main.run()
