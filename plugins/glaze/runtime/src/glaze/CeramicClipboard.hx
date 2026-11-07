// New code for the Haxe port of GPUI: the platform clipboard over Ceramic
// (`app.backend.clipboard`). Metadata handling follows gpui-pre-macos 0.3.10
// src/pasteboard.rs (Zed Industries, Apache-2.0), which keeps metadata next to
// the text and checks it with a hash of the text. See NOTICE.md.
package glaze;

/**
 * The system clipboard through Ceramic's backend (`getText` / `setText`):
 * plain text only. String entries are joined; images are dropped.
 *
 * Ceramic clipboards have no room for metadata, so the last item written is
 * remembered: when the clipboard still holds its text, reading returns that
 * item (with its metadata), like the macOS platform which stores metadata
 * next to the text and checks it against a hash of the text.
 */
class CeramicClipboard implements PlatformClipboard {

    var lastWritten:Null<ClipboardItem> = null;

    var lastWrittenText:Null<String> = null;

    public function new() {}

    public function readFromClipboard():Null<ClipboardItem> {
        final app = ceramic.App.app;
        if (app == null || app.backend == null)
            return null;
        final text = app.backend.clipboard.getText();
        if (text == null || text.length == 0)
            return null;
        if (lastWritten != null && text == lastWrittenText) {
            return lastWritten;
        }
        return ClipboardItem.newString(text);
    }

    public function writeToClipboard(item:ClipboardItem):Void {
        final app = ceramic.App.app;
        if (app == null || app.backend == null)
            return;
        final text = item.text();
        lastWritten = item;
        lastWrittenText = text != null ? text : '';
        app.backend.clipboard.setText(lastWrittenText);
    }

}
