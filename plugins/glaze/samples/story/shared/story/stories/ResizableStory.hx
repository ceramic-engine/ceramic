// Ported from gpui-kit 0.8.1: crates/story/src/stories/resizable_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.AnyElement;
import glaze.kit.base.resizable.PixelsRange;
import glaze.kit.base.resizable.Resizable.resizablePanel;
import glaze.kit.base.resizable.ResizablePanel;
import glaze.kit.base.resizable.ResizableState;
import glaze.kit.button.Button;
import glaze.kit.resizable.Resizable.hResizable;
import glaze.kit.resizable.Resizable.vResizable;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class ResizableStory extends Model implements Story {

    public static function title():String {
        return 'Resizable';
    }

    public static function description():String {
        return 'The resizable panels.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ResizableStory> {
        return cx.newEntity((c:Context<ResizableStory>) -> new ResizableStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var showLeft:Bool = true;

    @observe var useFlexNone:Bool = true;

    final programmaticState:Entity<ResizableState>;

    function new(_:Window, cx:Context<ResizableStory>) {
        super();
        focusHandle_ = cx.focusHandle();
        programmaticState = cx.app.newEntity((_:Context<ResizableState>) -> new ResizableState());
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    /** Rust returns an `AnyElement`; the element itself is kept here, the panels take any element. */
    static function panelBox(content:String, _:App):IntoElement {
        return div().p4().sizeFull().child(content);
    }

    function resizeProgrammatic(ix:Int, size:Float, window:Window, cx:App):Void {
        programmaticState.update(cx, (state, cx) -> state.resizePanel(ix, px(size), window, cx));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final app = cx.app;
        final left = resizablePanel()
            .visible(showLeft)
            .size(px(200.))
            .sizeRange(new PixelsRange(px(150.), px(400.)))
            .child(panelBox('Left', app));
        if (useFlexNone) left.flexNone();
        final right = resizablePanel()
            .size(px(280.))
            .sizeRange(new PixelsRange(px(200.), px(400.)))
            .child(panelBox('Right', app));
        if (useFlexNone) right.flexNone();
        return vFlex()
            .sizeFull()
            .itemsCenter()
            .gap6()
            .child(section('Nested Panels')
                .description('Combines horizontal and vertical splits with constrained panel sizes.')
                .wFull()
                .child(div()
                    .wFull()
                    .h(px(600.))
                    .border1()
                    .borderColor(theme.border)
                    .child(vResizable('resizable-1')
                        .onResize((state, _, cx) -> trace('Resized: ${state.read(cx).sizes()}'))
                        .child(hResizable('resizable-1.1')
                            .child(resizablePanel()
                                .size(px(150.))
                                .sizeRange(new PixelsRange(px(120.), px(300.)))
                                .child(panelBox('Left (120px .. 300px)', app)))
                            .child(panelBox('Center', app))
                            .child(resizablePanel()
                                .size(px(300.))
                                .child(panelBox('Right', app))))
                        .child(panelBox('Center', app))
                        .child(resizablePanel()
                            .size(px(80.))
                            .sizeRange(new PixelsRange(px(80.), glaze.Pixels.MAX))
                            .child(panelBox('Bottom (80px .. 150px)', app))))))
            .child(section('Growing Panel')
                .description('A flexible panel absorbs the space left by a constrained neighbor.')
                .wFull()
                .child(div()
                    .wFull()
                    .h(px(400.))
                    .border1()
                    .borderColor(theme.border)
                    .child(hResizable('resizable-3')
                        .child(resizablePanel()
                            .size(px(200.))
                            .sizeRange(new PixelsRange(px(200.), px(400.)))
                            .child(panelBox('Left 2', app)))
                        .child(panelBox('Right (Grow)', app)))))
            // Demonstrates `.flexNone()`. Toggle the left panel's
            // visibility while watching the right panel's width:
            //
            // - `Use flex_none = true` (default): right panel holds
            //   its width; the center flex panel absorbs the freed
            //   space.
            // - `Use flex_none = false`: right panel inherits the
            //   internal `flex_grow: 1` and absorbs half of the
            //   freed slack alongside the center.
            .child(section('Flex Behavior')
                .description('Compare fixed and growing panels while toggling visibility.')
                .wFull()
                .child(vFlex()
                    .wFull()
                    .gap2()
                    .child(storyToolbarGroup()
                        .child(Button.component('toggle-left')
                            .outline()
                            .label(showLeft ? 'Hide Left' : 'Show Left')
                            .onClick((_, _, _) -> showLeft = !showLeft))
                        .child(Button.component('toggle-flex-none')
                            .outline()
                            .label(useFlexNone ? 'Use flex_none: ON' : 'Use flex_none: OFF')
                            .onClick((_, _, _) -> useFlexNone = !useFlexNone)))
                    .child(div()
                        .wFull()
                        .h(px(200.))
                        .border1()
                        .borderColor(theme.border)
                        .child(hResizable('resizable-flex-none')
                            .child(left)
                            .child(panelBox('Center', app))
                            .child(right)))))
            // Programmatic resize: drive panel sizes via
            // `ResizableState.resizePanel(ix, size, window, cx)`. Buttons
            // mutate the shared state; subscribers (none here) would observe
            // a `ResizablePanelEvent.Resized` just like a drag-finish.
            .child(section('Programmatic Resize')
                .description('Panel sizes can be changed by actions as well as dragging.')
                .wFull()
                .child(vFlex()
                    .wFull()
                    .gap2()
                    .child(storyToolbarGroup()
                        .child(Button.component('compact-left')
                            .small()
                            .label('Compact left → 100')
                            .onClick((_, window, cx) -> resizeProgrammatic(0, 100., window, cx)))
                        .child(Button.component('reset-left')
                            .small()
                            .label('Reset left → 200')
                            .onClick((_, window, cx) -> resizeProgrammatic(0, 200., window, cx)))
                        .child(Button.component('compact-right')
                            .small()
                            .label('Compact right → 80')
                            .onClick((_, window, cx) -> resizeProgrammatic(2, 80., window, cx)))
                        .child(Button.component('reset-right')
                            .small()
                            .label('Reset right → 200')
                            .onClick((_, window, cx) -> resizeProgrammatic(2, 200., window, cx))))
                    .child(div()
                        .wFull()
                        .h(px(200.))
                        .border1()
                        .borderColor(theme.border)
                        .child(hResizable('resizable-programmatic')
                            .withState(programmaticState)
                            .child(resizablePanel()
                                .size(px(200.))
                                .child(panelBox('Left', app)))
                            .child(panelBox('Center (grow)', app))
                            .child(resizablePanel()
                                .size(px(200.))
                                .child(panelBox('Right', app)))))));
    }

}
