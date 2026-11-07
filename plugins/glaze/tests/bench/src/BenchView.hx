package;

import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

/**
 * A view rendering through a function.
 */
class BenchView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:glaze.Window, cx:glaze.Context<Dynamic>):glaze.IntoElement {
        return renderFn(window, cx);
    }

}
