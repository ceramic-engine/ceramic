// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/diagnostic_popover.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.input.DiagnosticEntry;
import glaze.kit.base.input.EditorState;
import glaze.kit.highlighter.DiagnosticStyles;
import glaze.kit.input.HoverPopover.Popover;

/**
 * The popover of the diagnostic under the pointer.
 */
class DiagnosticPopover extends Model implements Render {

    final state:WeakEntity<EditorState>;

    @:allow(glaze.kit.input, tests)
    final diagnostic:DiagnosticEntry;

    public static function create(diagnostic:DiagnosticEntry, state:Entity<EditorState>, cx:App):Entity<DiagnosticPopover> {
        return cx.newEntity((_:Context<DiagnosticPopover>) -> new DiagnosticPopover(diagnostic, state));
    }

    function new(diagnostic:DiagnosticEntry, state:Entity<EditorState>) {
        super();
        this.diagnostic = diagnostic;
        this.state = state.downgrade();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final state = this.state.upgrade();
        if (state == null) {
            return new Empty();
        }
        final message = diagnostic.message;

        final border = DiagnosticStyles.diagnosticBorder(diagnostic.severity, cx.app);
        final bg = DiagnosticStyles.diagnosticBackground(diagnostic.severity, cx.app);
        final fg = DiagnosticStyles.diagnosticForeground(diagnostic.severity, cx.app);

        return new Popover("diagnostic-popover", state, diagnostic.range, (window, cx) -> Popovers.renderMarkdown("message", message, window, cx))
            .px1()
            .py0p5()
            .bg(bg)
            .textColor(fg)
            .border1()
            .borderColor(border);
    }

}
