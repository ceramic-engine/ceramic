// New code for the Haxe port of gpui-kit (no Rust origin). See NOTICE.md.
package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.curve.CurveEditor;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.Lib.*;

using glaze.kit.base.StyledExt;

/** The curve editor (KIT-038): a timing curve, its pace, and the two handles of a bezier curve. */
class CurveEditorStory extends Model implements Story {

    public static function title():String {
        return 'CurveEditor';
    }

    public static function description():String {
        return 'Show a timing curve and edit a bezier curve by its handles.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<CurveEditorStory> {
        return cx.newEntity((c:Context<CurveEditorStory>) -> new CurveEditorStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var bezier:Array<Float> = [0.25, 0.1, 0.25, 1.];

    @observe var released:String = '';

    function new(_:Window, cx:Context<CurveEditorStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    /** A bounce that ends at 1, as a function of time. */
    static function bounce(time:Float):Float {
        final n = 7.5625;
        final d = 2.75;
        var t = time;
        if (t < 1 / d) return n * t * t;
        if (t < 2 / d) {
            t -= 1.5 / d;
            return n * t * t + 0.75;
        }
        if (t < 2.5 / d) {
            t -= 2.25 / d;
            return n * t * t + 0.9375;
        }
        t -= 2.625 / d;
        return n * t * t + 0.984375;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final numbers = [for (value in bezier) Std.string(value)].join(', ');
        return vFlex()
            .wFull()
            .gap3()
            .child(section('Bezier curve')
                .description('Drag the two handles. Time stays between 0 and 1, the value may go past for a curve that overshoots. The points under the curve show its pace.')
                .child(CurveEditor.component('bezier').bezier(bezier).w(px(236.)).h(px(176.)).border1().borderColor(theme.border)
                    .onChange((next, _, _) -> bezier = next)
                    .onRelease((next, _, _) -> released = next.join(', ')))
                .child(vFlex().gap1().w(px(300.))
                    .child(div().child('cubic-bezier($numbers)'))
                    .child(div().textSm().textColor(theme.mutedForeground).child(released != '' ? 'Released at $released' : 'Not released yet'))))
            .child(section('A function of time')
                .description('Any curve can be shown. It has no handles.')
                .child(CurveEditor.component('bounce').curve(bounce).w(px(236.)).h(px(176.)).border1().borderColor(theme.border)))
            .child(section('Faded handles')
                .description('A curve drawn with the handles of the bezier curve it is close to: dragging one would start from them.')
                .child(CurveEditor.component('faded').bezier([0.33, 1., 0.68, 1.]).curve(time -> 1. - Math.pow(1. - time, 3.)).faded(true)
                    .w(px(236.)).h(px(176.)).border1().borderColor(theme.border)))
            .child(section('Color, no pace, disabled')
                .description('The curve takes a color of its own, the pace points can be left out, and a disabled editor does not move.')
                .child(CurveEditor.component('colored').bezier([0.42, 0., 0.58, 1.]).color(theme.success).pace(false)
                    .w(px(180.)).h(px(130.)).border1().borderColor(theme.border))
                .child(CurveEditor.component('disabled').bezier([0.42, 0., 0.58, 1.]).disabled(true)
                    .w(px(180.)).h(px(130.)).border1().borderColor(theme.border)));
    }

}
