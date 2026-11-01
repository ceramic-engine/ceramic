// Ported from gpui-pre 0.3.10: src/elements/svg.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.io.Bytes;

/**
 * An SVG element, painted as a monochrome mask tinted with the text color
 * of its own style (`textColor(...)`), like GPUI. Create one with
 * `Prelude.svg()`, then give it a `path()` (loaded from the app's asset
 * source), an `externalPath()` (a file) or `data()`.
 *
 * Interactive methods: the common subset of GPUI's `InteractiveElement`
 * (`id`, `hover`, `groupHover`, `active`, `onMouseDown`, `onMouseUp`,
 * `onClick`, `onHover`, `tooltip`, `occlude`); the others are reachable
 * through `interactivity`.
 */
class Svg extends Element implements Styled {

    /** The interactivity of this element */
    public final interactivity:Interactivity = new Interactivity();

    var transformation:Null<Transformation> = null;

    var pathValue:Null<String> = null;

    var externalPathValue:Null<String> = null;

    var dataValue:Null<Bytes> = null;

    var dataPath:Null<String> = null;

    var hitbox:Null<Hitbox> = null;

    static final externalFiles:Map<String, Bytes> = new Map();

    public function new(#if gpui_inspector ?pos:haxe.PosInfos #end) {
        #if gpui_count_allocations gpui.util.AllocationCounters.svgs++; #end
        #if gpui_inspector
        interactivity.sourceLocation = pos;
        #end
    }

    #if gpui_inspector
    override function sourceLocation():Null<haxe.PosInfos> {
        return interactivity.sourceLocation;
    }
    #end

    public inline function style():StyleRefinement {
        return interactivity.baseStyle;
    }

    override function elementId():Null<ElementId> {
        return interactivity.elementId;
    }

    /** Set the path to the SVG file for this element (loaded from the asset source). */
    public function path(path:String):Svg {
        pathValue = path;
        return this;
    }

    /** Set the path to the SVG file for this element, read from the file system. */
    public function externalPath(path:String):Svg {
        externalPathValue = path;
        return this;
    }

    /** Set the SVG data directly (a deterministic path derived from it is used as the atlas key). */
    public function data(data:Bytes):Svg {
        dataValue = data;
        dataPath = '__binary_svg__' + haxe.crypto.Md5.make(data).toHex();
        return this;
    }

    /** Transform the SVG element with the given transformation. */
    public function withTransformation(transformation:Transformation):Svg {
        this.transformation = transformation;
        return this;
    }

/// InteractiveElement subset

    public function id(id:ElementIdArg):Svg {
        interactivity.elementId = id;
        return this;
    }

    public function group(group:String):Svg {
        interactivity.group = group;
        return this;
    }

    public function hover(f:StyleBuilder->StyleBuilder):Svg {
        interactivity.hoverStyle = StyleBuilder.build(f);
        return this;
    }

    public function groupHover(groupName:String, f:StyleBuilder->StyleBuilder):Svg {
        interactivity.groupHoverStyle = new Interactivity.GroupStyle(groupName, StyleBuilder.build(f));
        return this;
    }

    public function active(f:StyleBuilder->StyleBuilder):Svg {
        interactivity.activeStyle = StyleBuilder.build(f);
        return this;
    }

    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Svg {
        interactivity.onMouseDown(button, listener);
        return this;
    }

    public function onMouseUp(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Svg {
        interactivity.onMouseUp(button, listener);
        return this;
    }

    public function onClick(listener:(ClickEvent, Window, App) -> Void):Svg {
        interactivity.onClick(listener);
        return this;
    }

    public function onHover(listener:(Bool, Window, App) -> Void):Svg {
        interactivity.onHover(listener);
        return this;
    }

    public function tooltip(buildTooltip:(Window, App) -> AnyView):Svg {
        interactivity.tooltip(buildTooltip);
        return this;
    }

    public function occlude():Svg {
        interactivity.occludeMouse();
        return this;
    }

/// Element

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return interactivity.requestLayout(id, #if gpui_inspector inspectorId, #end window, cx, (style, window, cx) -> window.requestLayout(style, null, cx));
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = interactivity.prepaint(id, #if gpui_inspector inspectorId, #end bounds, bounds.size, window, cx, (_, _, hitbox, _, _) -> hitbox);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        this.hitbox = null;
        interactivity.paint(id, #if gpui_inspector inspectorId, #end bounds, hitbox, window, cx, (style, window, cx) -> {
            final transformation = this.transformation != null ? this.transformation.intoMatrix(bounds.center(), window.scaleFactor()) : null;
            final color:Null<Hsla> = style.text != null ? style.text.color : null;
            if (color == null)
                return;
            try {
                if (dataValue != null && dataPath != null) {
                    window.paintSvg(bounds, dataPath, dataValue, transformation, color, cx);
                }
                else if (externalPathValue != null) {
                    final bytes = loadExternal(externalPathValue);
                    if (bytes == null)
                        return;
                    window.paintSvg(bounds, externalPathValue, bytes, transformation, color, cx);
                }
                else if (pathValue != null) {
                    window.paintSvg(bounds, pathValue, null, transformation, color, cx);
                }
            }
            catch (e:Dynamic) {
                ceramic.Shortcuts.log.error('Failed to paint svg: $e');
            }
        });
    }

    static function loadExternal(path:String):Null<Bytes> {
        var bytes = externalFiles.get(path);
        if (bytes == null) {
            #if (sys || (web && ceramic_use_electron))
            if (ceramic.Files.exists(path))
                bytes = ceramic.Files.getBytes(path);
            #end
            if (bytes != null)
                externalFiles.set(path, bytes);
        }
        return bytes;
    }

}

/**
 * A transformation to apply to an SVG element.
 */
class Transformation {

    public final scale:Size;

    public final translate:Point;

    public final rotate:Radians;

    public function new(?scale:Size, ?translate:Point, rotate:Radians = 0.0) {
        this.scale = scale != null ? scale : new Size(1, 1);
        this.translate = translate != null ? translate : new Point(0, 0);
        this.rotate = rotate;
    }

    /** Create a new Transformation with the specified scale along each axis. */
    public static function scaled(scale:Size):Transformation {
        return new Transformation(scale);
    }

    /** Create a new Transformation with the specified translation. */
    public static function translated(translate:Point):Transformation {
        return new Transformation(null, translate);
    }

    /** Create a new Transformation with the specified rotation in radians. */
    public static function rotated(rotate:Radians):Transformation {
        return new Transformation(null, null, rotate);
    }

    /** Update the scaling factor of this transformation. */
    public function withScaling(scale:Size):Transformation {
        return new Transformation(scale, translate, rotate);
    }

    /** Update the translation value of this transformation. */
    public function withTranslation(translate:Point):Transformation {
        return new Transformation(scale, translate, rotate);
    }

    /** Update the rotation angle of this transformation. */
    public function withRotation(rotate:Radians):Transformation {
        return new Transformation(scale, translate, rotate);
    }

    /**
     * The matrix in scaled pixels, around `center` (read it bottom up:
     * translate to the origin, scale, rotate, translate back plus the offset).
     */
    public function intoMatrix(center:Point, scaleFactor:Float):TransformationMatrix {
        return TransformationMatrix.unit()
            .translate(center.x * scaleFactor + translate.x * scaleFactor, center.y * scaleFactor + translate.y * scaleFactor)
            .rotate(rotate)
            .scale(scale.width, scale.height)
            .translate(-center.x * scaleFactor, -center.y * scaleFactor);
    }

}
