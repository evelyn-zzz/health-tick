import SwiftUI
import AppKit

@MainActor
enum ShareManager {

    private static var previewWindow: NSWindow?

    /// Render the share card to an NSImage at @2x scale
    static func renderCard(data: ShareCardData) -> NSImage? {
        let view = ShareCardView(data: data)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(
                width: CGFloat(cgImage.width) / 2.0,
                height: CGFloat(cgImage.height) / 2.0
            )
        )
    }

    /// Show a preview window with the share card image
    static func showPreview(data: ShareCardData) {
        guard let image = renderCard(data: data) else { return }

        // Close existing preview if any
        previewWindow?.close()

        let previewView = SharePreviewView(image: image)
        let hostingView = NSHostingView(rootView: previewView)

        let hostingSize = hostingView.fittingSize
        let windowWidth = hostingSize.width
        let windowHeight = hostingSize.height

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        previewWindow = window
    }
}

// MARK: - Preview Window View

struct SharePreviewView: View {
    let image: NSImage
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([image])
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(copied ? L.shareCopied : L.shareCopyAction)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(.white)
                    .background(copied ? Color.gray : Color.green, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.borderless)

                Button {
                    let picker = NSSharingServicePicker(items: [image])
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        picker.show(
                            relativeTo: contentView.bounds,
                            of: contentView,
                            preferredEdge: .minY
                        )
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text(L.shareMore)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(width: 410)
    }
}
