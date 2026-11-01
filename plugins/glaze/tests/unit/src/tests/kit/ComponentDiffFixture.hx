// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`fixture`, test only)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.component.diff.DiffFile;
import similar.ChangeTag;
import similar.TextDiff;

/**
 * Test fixtures describe complete file versions; they are turned into a
 * full-context patch and pass through the production parser.
 */
class ComponentDiffFixture {

    /** The largest line number (Rust `usize::MAX` in the tests). */
    public static inline final MAX:Int = 0x7FFFFFFF;

    static function quoted(name:String):String {
        return '"' + name.split('\\').join('\\\\').split('"').join('\\"').split('\n').join('\\n').split('\r').join('\\r').split('\t').join('\\t') + '"';
    }

    /** Rust `split_inclusive('\n')`. */
    public static function splitInclusive(text:String):Array<String> {
        final rv = [];
        var unit = 0;
        while (unit < text.length) {
            final next = text.indexOf('\n', unit);
            final end = next == -1 ? text.length : next + 1;
            rv.push(text.substring(unit, end));
            unit = end;
        }
        return rv;
    }

    /**
     * Builds a document from optional complete sources (`[name, text]`).
     * Hunk rows are removed because these fixtures predate hunk navigation.
     */
    public static function document(original:Null<Array<String>>, modified:Null<Array<String>>):DiffFile {
        final old = original == null ? '' : original[1];
        final newText = modified == null ? '' : modified[1];
        final oldLines = splitInclusive(old);
        final newLines = splitInclusive(newText);
        final oldName = original == null ? '/dev/null' : quoted(original[0]);
        final newName = modified == null ? '/dev/null' : quoted(modified[0]);
        // Write one full-context hunk directly: `similar`'s unified writer
        // does not preserve CRLF line endings.
        final diff = TextDiff.fromSlices(oldLines, newLines);
        final patch = new StringBuf();
        patch.add('--- $oldName\n+++ $newName\n');
        if (oldLines.length > 0 || newLines.length > 0) {
            patch.add('@@ -' + (oldLines.length > 0 ? 1 : 0) + ',' + oldLines.length + ' +' + (newLines.length > 0 ? 1 : 0) + ',' + newLines.length + ' @@\n');
            for (op in diff.ops()) {
                for (change in diff.iterChanges(op)) {
                    patch.add(switch (change.tag()) {
                        case ChangeTag.Equal: ' ';
                        case ChangeTag.Delete: '-';
                        case ChangeTag.Insert: '+';
                    });
                    patch.add(change.value());
                    if (!StringTools.endsWith(change.value(), '\n'))
                        patch.add('\n\\ No newline at end of file\n');
                }
            }
        }
        var text = patch.toString();
        if (original == null)
            text = 'diff --git a/fixture b/fixture\nnew file mode 100644\n' + text;
        else if (modified == null)
            text = 'diff --git a/fixture b/fixture\ndeleted file mode 100644\n' + text;
        final document = DiffFile.parse(text)[0];
        @:privateAccess document.inner.hunks.resize(0);
        return document;
    }

    public static function modified(name:String, original:String, modified:String):DiffFile {
        return document([name, original], [name, modified]);
    }

}
