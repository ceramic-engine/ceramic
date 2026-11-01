// Ported from gpui-kit 0.8.1: crates/story/src/stories/mod.rs (trait Story, static part)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

#if !macro
import gpui.AnyView;
import gpui.App;
import gpui.Hsla;
import gpui.Pixels;
import gpui.Window;
import gpui.component.dock.PanelControl;
#end

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

/**
 * The static functions of a `Story` (see `Story`), gathered with the
 * trait's defaults by `StoryMeta.of(XStory)`.
 */
class StoryMeta {

    #if !macro

    public final klass:String;

    public final title:String;

    public final description:String;

    public final closable:Bool;

    public final zoomable:Null<PanelControl>;

    public final titleBg:Null<Hsla>;

    public final paddings:Pixels;

    /** `S::new_view`. */
    public final newView:(Window, App) -> AnyView;

    /** `S::on_active_any`. */
    public final onActiveAny:(AnyView, Bool, Window, App) -> Void;

    public function new(klass:String, title:String, description:String, closable:Bool, zoomable:Null<PanelControl>, titleBg:Null<Hsla>,
            paddings:Pixels, newView:(Window, App) -> AnyView, onActiveAny:(AnyView, Bool, Window, App) -> Void) {
        this.klass = klass;
        this.title = title;
        this.description = description;
        this.closable = closable;
        this.zoomable = zoomable;
        this.titleBg = titleBg;
        this.paddings = paddings;
        this.newView = newView;
        this.onActiveAny = onActiveAny;
    }

    #end

    /**
     * The static part of the story class `cls` (a type path), with the
     * trait's defaults for the functions it does not declare.
     */
    macro public static function of(cls:Expr):ExprOf<StoryMeta> {
        final path = typePath(cls);
        // No try/catch: a type error inside the story is reported as is.
        final type = Context.getType(path);
        return build(path, type, cls.pos);
    }

    /**
     * Like `of`, but `null` when the class does not exist (yet): the gallery
     * lists every story of the original, some of them ported later or not at
     * all (the stories that need OS services the port has no access to).
     */
    macro public static function optional(cls:Expr):ExprOf<Null<StoryMeta>> {
        final path = typePath(cls);
        if (!classExists(path)) return macro null;
        final type = Context.getType(path);
        return build(path, type, cls.pos);
    }

    /**
     * Calls the module `init` of a story (`XStory.init(cx)`, Rust
     * `x_story::init(cx)`), when the class exists (see `optional`).
     */
    macro public static function initOptional(cls:Expr, cx:Expr):Expr {
        final path = typePath(cls);
        if (!classExists(path)) return macro {};
        final type = Context.getType(path);
        final ref = switch type {
            case TInst(ref, _): ref.get();
            case _: Context.error('$path is not a class', cls.pos);
        }
        final parts = ref.pack.copy();
        parts.push(ref.name);
        final ref = Context.parse(parts.join('.'), cls.pos);
        return macro $ref.init($cx);
    }

    #if macro

    /**
     * Whether the module of `path` exists on the class path. Only a missing
     * file makes a story optional: a story that exists but does not compile
     * reports its own errors instead of being silently left out.
     */
    static function classExists(path:String):Bool {
        return try {
            Context.resolvePath(path.split('.').join('/') + '.hx');
            true;
        } catch (e:Dynamic) false;
    }

    static function typePath(e:Expr):String {
        return switch e.expr {
            case EConst(CIdent(name)) | EConst(CString(name, _)): name;
            case EField(_, _): haxe.macro.ExprTools.toString(e);
            case _: Context.error('Expected a story class', e.pos);
        }
    }

    static function build(path:String, type:Type, pos:Position):Expr {
        final cls = switch type {
            case TInst(ref, _): ref.get();
            case _: Context.error('$path is not a class', pos);
        }
        final parts = cls.pack.copy();
        parts.push(cls.name);
        final ref:Expr = Context.parse(parts.join('.'), pos);
        final statics = [for (field in cls.statics.get()) field.name => true];
        var hasOnActive = false;
        var current:Null<ClassType> = cls;
        while (current != null && !hasOnActive) {
            for (field in current.fields.get()) if (field.name == 'onActive') hasOnActive = true;
            current = current.superClass != null ? current.superClass.t.get() : null;
        }
        if (!statics.exists('title')) Context.error('$path has no static title()', pos);
        if (!statics.exists('newView')) Context.error('$path has no static newView()', pos);

        final klass = macro $v{cls.name};
        final title = macro $ref.title();
        final description = statics.exists('description') ? macro $ref.description() : macro '';
        final closable = statics.exists('closable') ? macro $ref.closable() : macro true;
        final zoomable = statics.exists('zoomable') ? macro $ref.zoomable() : macro gpui.component.dock.PanelControl.defaultValue();
        final titleBg = statics.exists('titleBg') ? macro $ref.titleBg() : macro null;
        final paddings = statics.exists('paddings') ? macro $ref.paddings() : macro 16.;
        final onActive = hasOnActive
            ? macro (view:gpui.AnyView, active:Bool, window:gpui.Window, cx:gpui.App) -> {
                final story = Std.downcast((view : gpui.Model), $ref);
                if (story != null) {
                    cx.updateEntity(story, (story, cx) -> story.onActive(active, window, cx));
                }
            }
            : macro (view:gpui.AnyView, active:Bool, window:gpui.Window, cx:gpui.App) -> {};

        // The expression is built in a generated class of its own and reached
        // with `new` (a type path), so that a local variable of the call site
        // named like a package (`story`) cannot shadow the class paths.
        final helperName = 'StoryMeta_' + parts.join('_');
        final helperExists = try Context.getType('story.meta.' + helperName) != null catch (e:Dynamic) false;
        if (!helperExists) {
            final body = macro return new story.StoryMeta($klass, $title, $description, $closable, $zoomable, $titleBg, $paddings,
                (window:gpui.Window, cx:gpui.App) -> ($ref.newView(window, cx) : gpui.AnyView), $onActive);
            final helper = macro class $helperName {
                public function new() {}
                public function meta():story.StoryMeta $body;
            };
            helper.pack = ['story', 'meta'];
            Context.defineType(helper);
        }
        final created:Expr = {expr: ENew({pack: ['story', 'meta'], name: helperName}, []), pos: pos};
        return {expr: ECall({expr: EField(created, 'meta'), pos: pos}, []), pos: pos};
    }

    #end

}
