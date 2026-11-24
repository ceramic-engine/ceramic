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
import glaze.kit.Size;
import glaze.kit.dial.AngleDial;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;
import story.Lib.*;

using glaze.kit.base.StyledExt;

/** The angle dial (KIT-037): an angle shown by a needle, turned by a press or a drag. */
class AngleDialStory extends Model implements Story {

    public static function title():String {
        return 'AngleDial';
    }

    public static function description():String {
        return 'Show an angle and turn it.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<AngleDialStory> {
        return cx.newEntity((c:Context<AngleDialStory>) -> new AngleDialStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var free:Float = 15.;

    @observe var stepped:Float = 90.;

    @observe var released:Float = 90.;

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(_:Window, cx:Context<AngleDialStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Press anywhere on the dial to point the needle there, drag to turn it. Turning past a full turn keeps counting.')
                .child(AngleDial.component('free').withSize(size).value(free).onChange((degrees, _, _) -> free = degrees))
                .child(div().w(px(130.)).textColor(theme.mutedForeground).child('${free} degrees')))
            .child(section('Step')
                .description('The needle stops on multiples of 15 degrees. The second value is told when the pointer is released.')
                .child(AngleDial.component('stepped').withSize(size).value(stepped).step(15.)
                    .onChange((degrees, _, _) -> stepped = degrees)
                    .onRelease((degrees, _, _) -> released = degrees))
                .child(div().w(px(260.)).textColor(theme.mutedForeground).child('${stepped} degrees, released at ${released}')))
            .child(section('Sizes')
                .description('From extra small to large.')
                .child(AngleDial.component('xsmall').withSize(glaze.kit.Size.XSmall).value(free).onChange((degrees, _, _) -> free = degrees))
                .child(AngleDial.component('small').withSize(glaze.kit.Size.Small).value(free).onChange((degrees, _, _) -> free = degrees))
                .child(AngleDial.component('medium').withSize(glaze.kit.Size.Medium).value(free).onChange((degrees, _, _) -> free = degrees))
                .child(AngleDial.component('large').withSize(glaze.kit.Size.Large).value(free).onChange((degrees, _, _) -> free = degrees)))
            .child(section('Color and disabled')
                .description('The needle takes a color of its own. A disabled dial shows its angle and tells nothing.')
                .child(AngleDial.component('colored').withSize(size).value(free).color(theme.success).onChange((degrees, _, _) -> free = degrees))
                .child(AngleDial.component('disabled').withSize(size).value(free).disabled(true)));
    }

}
