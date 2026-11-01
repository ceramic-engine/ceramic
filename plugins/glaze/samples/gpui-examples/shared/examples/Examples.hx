package examples;

import gpui.AnyView;
import gpui.App;
import gpui.Window;
import examples.showcase.BaseShowcase;

/**
 * The ported GPUI examples (and pages of gpui-kit's base showcase), as
 * `run_example` would open them: the window
 * size, what `run_example` does on the app before opening the window
 * (`setup`) and the root view (`open`, the closure given to `open_window`).
 * Used by the `gpui-examples` sample and by the golden scenarios
 * (`test/golden/src/ExampleScenarios.hx`).
 */
class Examples {

    public static final ALL:Array<ExampleInfo> = [
        {
            id: 'hello_world',
            width: HelloWorld.WIDTH,
            height: HelloWorld.HEIGHT,
            open: (window, cx) -> HelloWorld.open(window, cx)
        },
        {
            id: 'uniform_list',
            width: UniformListExample.WIDTH,
            height: UniformListExample.HEIGHT,
            open: (window, cx) -> UniformListExample.open(window, cx)
        },
        {
            id: 'text_wrapper',
            width: TextWrapper.WIDTH,
            height: TextWrapper.HEIGHT,
            open: (window, cx) -> TextWrapper.open(window, cx)
        },
        {
            id: 'tab_stop',
            width: TabStop.WIDTH,
            height: TabStop.HEIGHT,
            setup: TabStop.setup,
            open: (window, cx) -> TabStop.open(window, cx)
        },
        {
            id: 'drag_drop',
            width: DragDrop.WIDTH,
            height: DragDrop.HEIGHT,
            open: (window, cx) -> DragDrop.open(window, cx)
        },
        {
            id: 'shadow',
            width: Shadow.WIDTH,
            height: Shadow.HEIGHT,
            open: (window, cx) -> Shadow.open(window, cx)
        },
        {
            id: 'animation',
            width: AnimationExample.WIDTH,
            height: AnimationExample.HEIGHT,
            open: (window, cx) -> AnimationExample.open(window, cx)
        },
        // gpui-kit's base showcase (the pages of ported components)
        {
            id: 'showcase_avatar',
            width: BaseShowcase.WIDTH,
            height: BaseShowcase.HEIGHT,
            setup: BaseShowcase.setup,
            open: (window, cx) -> BaseShowcase.open('avatar')(window, cx)
        },
        {
            id: 'showcase_link',
            width: BaseShowcase.WIDTH,
            height: BaseShowcase.HEIGHT,
            setup: BaseShowcase.setup,
            open: (window, cx) -> BaseShowcase.open('link')(window, cx)
        },
        {
            id: 'showcase_progress',
            width: BaseShowcase.WIDTH,
            height: BaseShowcase.HEIGHT,
            setup: BaseShowcase.setup,
            open: (window, cx) -> BaseShowcase.open('progress')(window, cx)
        }
    ];

    public static function find(id:String):Null<ExampleInfo> {
        for (example in ALL) {
            if (example.id == id) return example;
        }
        return null;
    }

}

@:structInit
class ExampleInfo {

    /**
     * The name of the Rust example (`examples/<id>.rs`).
     */
    public final id:String;

    public final width:Float;

    public final height:Float;

    @:optional public final setup:Null<App->Void>;

    public final open:(Window, App) -> AnyView;

}
