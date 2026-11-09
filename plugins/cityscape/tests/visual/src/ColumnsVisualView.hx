// New code for Cityscape (not a port): the column positions of wide text
// compared with the real Monaco.
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Column x positions of wide text (`CITYSCAPE_VISUAL_SCENE=columns`): the
 * lines of the recorded Monaco truth `wide-columns.json` (ASCII, CJK, kana,
 * Hangul, emoji sequences, full width punctuation; JetBrains Mono 14 with the
 * fallback fonts of the platform), in one editor with the options of the
 * recording. Each glyph keeps its fallback font's advance, like Monaco's DOM.
 *
 * Once the frames settled, `CityscapeView.getOffsetForColumn` of every column
 * is compared with the truth's unrounded DOM positions (`xFloat`), within
 * `WideColumns.TOLERANCE`. With `CITYSCAPE_VISUAL_COLUMNS_OUT` set, the
 * positions and the comparison are written there as JSON (on the web through
 * the Electron runner). This is the web half of the check: the headless Node
 * unit run has no canvas, so no fallback font for emoji and CJK (the unit
 * test `WideColumnsTest` checks native targets and the ASCII prefix on Node).
 */
class ColumnsVisualView extends Model implements Render {

    final context:Cityscape;

    final model:TextModel;

    final truth:WideColumns;

    var view:Null<Entity<CityscapeView>> = null;

    public function new(cx:Context<ColumnsVisualView>) {
        super();
        truth = WideColumns.parse(Embed.file('../../unit/data/monaco/wide-columns.json'));
        context = new Cityscape();
        context.themeService.setTheme('vs-dark');
        model = new TextModel(truth.text, 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().flex().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeEditor.component().model(model).context(context).options(truth.editorOptions())
                    .onCreate(e -> view = e.getView()).flex1()
            );
    }

    /**
     * Compares the columns with the truth and writes the result to `out`
     * when given. Returns false while the view is not ready.
     */
    public function check(out:Null<String>):Bool {
        if (view == null) {
            return false;
        }
        final v:CityscapeView = view;
        final os = ceramic.App.app.backend.info.operatingSystem();
        final report = truth.compare((line, column) -> v.getOffsetForColumn(line, column), WideColumns.knownDifferences(os, #if web true #else false #end), false);
        log.info('wide columns: ' + report.summary());
        if (out != null && out != '') {
            ceramic.Files.saveContent(out, report.toJson());
        }
        return true;
    }

}
