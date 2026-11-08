// Ported from gpui-kit 0.8.1: crates/base/src/input/textarea/mod.rs (`Textarea`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Component;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Window;

using glaze.kit.base.input.InputTokenPresentation;

/**
 * An unstyled ordinary multi-line text input.
 */
class Textarea extends Component {

    var presentation:InlineTokenPresentation = new InlineTokenPresentation();

    final state:Entity<TextareaState>;

    public function new(state:Entity<TextareaState>) {
        super();
        this.state = state;
    }

    /** The element each atomic token renders as; the input keeps editing and history. */
    public function token(render:(InlineTokenContext, Window, App) -> IntoElement):Textarea {
        presentation = presentation.token(render);
        return this;
    }

    /** Open a reference after a completed, unconsumed token click. */
    public function onTokenClick(listener:InlineTokenClickListener):Textarea {
        presentation = presentation.onTokenClick(listener);
        return this;
    }

    /** Report pointer presence over a token; hover never selects or edits. */
    public function onTokenHover(listener:InlineTokenHoverListener):Textarea {
        presentation = presentation.onTokenHover(listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final presentation = this.presentation;
        state.update(cx, (state, _) -> state.setTokenPresentation(presentation));
        return state;
    }

}
