package;

import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;

/**
 * A view rendering through a function.
 */
class BenchView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:gpui.Window, cx:gpui.Context<Dynamic>):gpui.IntoElement {
        return renderFn(window, cx);
    }

}
