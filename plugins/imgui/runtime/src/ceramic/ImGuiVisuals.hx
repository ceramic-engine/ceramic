package ceramic;

#if plugin_imgui

import ceramic.Shortcuts.*;
import imgui.ImGui;

/**
 * Display ceramic visuals inside Dear ImGui layouts.
 *
 * Call `ImGuiVisuals.visual(myVisual)` anywhere between ImGui widgets: the
 * visual is rendered offscreen (through a `Filter`) and displayed with
 * `ImGui.image()`. Immediate-mode friendly: call it every frame, entries are
 * created/reused/released automatically.
 *
 * - The visual is REPARENTED into the filter content while displayed (same
 *   semantics as elements' Im.visual()): it leaves its previous parent, and
 *   is deactivated (never destroyed) when no longer displayed.
 * - Small/medium visuals share a single render texture atlas
 *   (`TextureTilePacker`, pages chained automatically); visuals larger than
 *   a page get their own render texture.
 * - Pointer events work: the filter is invisibly aligned with the ImGui
 *   image rect, so `onPointerDown/Up/Over/...` on the content visuals behave
 *   normally (gated by ImGui hover, so ImGui window occlusion is respected).
 * - Cross-target: pure ceramic + portable ImGui facade.
 */
class ImGuiVisuals {

    /** Frames an entry is kept alive after its visual stops being displayed. */
    public static var gracePeriodFrames:Int = 120;

    /** Number of active entries (displayed this frame or in grace period). */
    public static var numEntries(default, null):Int = 0;

    /** Number of entries currently using a dedicated render texture (not the shared atlas). */
    public static var numDedicated(default, null):Int = 0;

    static var entries:Map<Visual, ImGuiVisualEntry> = new Map();

    static var currentFrame:Int = 0;

    // One shared packer per (antialiasing, textureFilter) combination:
    // these are render texture level settings, they cannot vary per tile.
    static var sharedPackers:Map<Int, TextureTilePacker> = new Map();

    // Packer cell settings (mirror TextureTilePacker defaults)
    static inline var PAD_WIDTH:Int = 16;
    static inline var PAD_HEIGHT:Int = 16;
    static inline var MARGIN:Int = 1;

    /**
     * Display `visual` inside the current ImGui layout.
     * Without explicit size, uses the visual's own width/height. With a
     * size, the visual is scaled to fit (uniform) and centered.
     * With `interactive` (default), ceramic pointer events are redirected to
     * the content when the image is hovered.
     * `antialiasing` (MSAA samples) and `textureFilter` (LINEAR default,
     * NEAREST for pixel-art) select the offscreen texture settings: visuals
     * sharing the same settings share the same atlas.
     * With `nativeResolution`, the visual is rendered offscreen at its OWN
     * size and the image is scaled to the display size (use it with NEAREST
     * for pixel-art, or to display a game at its native resolution); by
     * default the visual is rendered directly at display resolution.
     */
    public static function visual(visual:Visual, width:Float = -1, height:Float = -1, interactive:Bool = true, antialiasing:Int = 0, ?textureFilter:TextureFilter, nativeResolution:Bool = false):Void {

        var entry = touch(visual, width, height, antialiasing, textureFilter, nativeResolution);
        if (entry == null)
            return;

        submitImage(entry, interactive, null);

    }

    /**
     * Like `visual()`, but displayed as an ImGui button. Returns true when clicked.
     */
    public static function visualButton(id:String, visual:Visual, width:Float = -1, height:Float = -1, interactive:Bool = false, antialiasing:Int = 0, ?textureFilter:TextureFilter, nativeResolution:Bool = false):Bool {

        var entry = touch(visual, width, height, antialiasing, textureFilter, nativeResolution);
        if (entry == null)
            return false;

        return submitImage(entry, interactive, id);

    }

    /**
     * Display any ceramic texture (thin wrapper over ImGui.image + textureRef).
     */
    public static function texture(texture:Texture, width:Float = -1, height:Float = -1):Void {

        if (texture == null || texture.destroyed)
            return;
        if (width < 0) width = texture.width;
        if (height < 0) height = texture.height;
        ImGui.image(ImGuiTextures.textureRef(texture), ImVec2.make(width, height));

    }

    /**
     * Display a ceramic TextureTile (sub-region of a texture), UVs computed.
     */
    public static function tile(tile:TextureTile, width:Float = -1, height:Float = -1):Void {

        if (tile == null || tile.texture == null || tile.texture.destroyed)
            return;
        if (width < 0) width = tile.frameWidth;
        if (height < 0) height = tile.frameHeight;
        var tex = tile.texture;
        var uv0 = ImVec2.make(tile.frameX / tex.width, tile.frameY / tex.height);
        var uv1 = ImVec2.make((tile.frameX + tile.frameWidth) / tex.width, (tile.frameY + tile.frameHeight) / tex.height);
        ImGui.imageEx(ImGuiTextures.textureRef(tex), ImVec2.make(width, height), uv0, uv1);

    }

    /**
     * Whether the ImGui window that displayed `visual` (last submit) is
     * focused (root or child windows). Useful to route keyboard input to a
     * game/scene displayed inside an ImGui window:
     * read `app.input` only when its window is focused.
     */
    public static function isWindowFocused(visual:Visual):Bool {
        var entry = entries.get(visual);
        return entry != null && entry.windowFocused;
    }

    /**
     * Whether the displayed image of `visual` is currently hovered
     * (as reported by ImGui, so ImGui window occlusion is respected).
     */
    public static function isHovered(visual:Visual):Bool {
        var entry = entries.get(visual);
        return entry != null && entry.hovered;
    }

    // =========================================================================
    // Internals
    // =========================================================================

    /** Get or create the entry for `visual`, mark it used this frame, sync sizes/settings. */
    static function touch(visual:Visual, width:Float, height:Float, antialiasing:Int, textureFilter:TextureFilter, nativeResolution:Bool):ImGuiVisualEntry {

        if (visual == null || visual.destroyed)
            return null;

        if (width <= 0) width = visual.width;
        if (height <= 0) height = visual.height;
        if (width <= 0 || height <= 0)
            return null;

        // Offscreen texture area: display size by default (render at the
        // displayed resolution), or the visual's own size in native mode.
        var filterWidth = nativeResolution ? visual.width : width;
        var filterHeight = nativeResolution ? visual.height : height;
        if (filterWidth <= 0 || filterHeight <= 0)
            return null;

        var entry = entries.get(visual);
        if (entry == null) {
            entry = new ImGuiVisualEntry(visual);
            entries.set(visual, entry);
            numEntries++;
            visual.onDestroy(null, _ -> {
                var e = entries.get(visual);
                if (e != null) {
                    if (e.dedicated) numDedicated--;
                    entries.remove(visual);
                    numEntries--;
                    e.dispose(false);
                }
            });
        }

        entry.lastUsedFrame = currentFrame;
        entry.displayWidth = width;
        entry.displayHeight = height;
        entry.ensureFilter(Math.ceil(filterWidth), Math.ceil(filterHeight), antialiasing, textureFilter == NEAREST);
        entry.attach();
        entry.layoutContent(nativeResolution);

        return entry;

    }

    /** Submit the ImGui image (or image button) + align the filter for hits. */
    static function submitImage(entry:ImGuiVisualEntry, interactive:Bool, buttonId:String):Bool {

        var filter = entry.filter;
        var renderTexture = filter.renderTexture;
        if (renderTexture == null) {
            // First frame: the filter's render texture is created during
            // `computeContent` which may not have run yet. Display a dummy
            // spacing so the layout stays stable, texture shows next frame.
            ImGui.dummy(ImVec2.make(entry.displayWidth, entry.displayHeight));
            return false;
        }

        var texRef = ImGuiTextures.textureRef(renderTexture);
        var size = ImVec2.make(entry.displayWidth, entry.displayHeight);

        var uv0:ImVec2;
        var uv1:ImVec2;
        var textureTile = filter.textureTile;
        if (textureTile != null) {
            uv0 = ImVec2.make(textureTile.frameX / renderTexture.width, textureTile.frameY / renderTexture.height);
            uv1 = ImVec2.make(
                (textureTile.frameX + entry.width) / renderTexture.width,
                (textureTile.frameY + entry.height) / renderTexture.height
            );
        }
        else {
            uv0 = ImVec2.make(0, 0);
            uv1 = ImVec2.make(entry.width / renderTexture.width, entry.height / renderTexture.height);
        }

        var clicked = false;
        if (buttonId != null) {
            clicked = ImGui.imageButtonEx(buttonId, texRef, size, uv0, uv1, ImVec4.make(0, 0, 0, 0), ImVec4.make(1, 1, 1, 1));
        }
        else {
            ImGui.imageEx(texRef, size, uv0, uv1);
        }

        // Redirect ceramic pointer events: align the (never drawn) hit proxy
        // quad with the on-screen ImGui item rect. The item rect (ImGui
        // coordinates, single viewport) is first mapped to ceramic logical
        // screen coordinates (identity mapping unless
        // `ImGuiSystem.nativeScreen` is enabled). The proxy is the filter's
        // `hitVisual`: `visualInContentHits` concats the tested visual's
        // matrix (RENDER TEXTURE coordinates, which include the atlas tile
        // offset) with the proxy's matrix, so the proxy transform must map
        // RT coordinates to screen: compensate the tile offset.
        var rectMin = ImGui.getItemRectMin();
        var rectMax = ImGui.getItemRectMax();
        var hovered = ImGui.isItemHovered();
        var system = ImGuiSystem.shared;
        var screenMinX = system.imGuiToScreenX(rectMin.x, rectMin.y);
        var screenMinY = system.imGuiToScreenY(rectMin.x, rectMin.y);
        var screenMaxX = system.imGuiToScreenX(rectMax.x, rectMax.y);
        var screenMaxY = system.imGuiToScreenY(rectMax.x, rectMax.y);
        var displayedW = screenMaxX - screenMinX;
        var displayedH = screenMaxY - screenMinY;
        var scaleX = entry.width > 0 ? displayedW / entry.width : 1.0;
        var scaleY = entry.height > 0 ? displayedH / entry.height : 1.0;
        var tileX = 0.0;
        var tileY = 0.0;
        if (textureTile != null) {
            tileX = textureTile.frameX;
            tileY = textureTile.frameY;
        }
        var hitProxy = entry.hitProxy;
        hitProxy.pos(screenMinX - tileX * scaleX, screenMinY - tileY * scaleY);
        hitProxy.scale(scaleX, scaleY);
        // Sized so that (tile offset + area) * scale ends exactly at rectMax;
        // the extra left/top margin is harmless: hits are gated by hover.
        hitProxy.size(tileX + entry.width, tileY + entry.height);
        var touchable = interactive && hovered;
        hitProxy.touchable = touchable;
        filter.touchable = touchable; // Gates the content's computedTouchable chain

        // Focus/hover state, queryable with isWindowFocused()/isHovered()
        entry.hovered = hovered;
        entry.windowFocused = ImGui.isWindowFocused(ImGuiFocusedFlags.RootWindow | ImGuiFocusedFlags.ChildWindows);

        return clicked;

    }

    /** Shared atlas packer for the given settings (lazy, one per combination). */
    @:allow(ceramic.ImGuiVisualEntry)
    static function packer(antialiasing:Int, nearest:Bool):TextureTilePacker {
        var key = antialiasing | (nearest ? 0x10000 : 0);
        var p = sharedPackers.get(key);
        if (p == null) {
            p = new TextureTilePacker(true, -1, -1, PAD_WIDTH, PAD_HEIGHT, MARGIN, antialiasing);
            p.texture.filter = nearest ? NEAREST : LINEAR;
            sharedPackers.set(key, p);
        }
        return p;
    }

    /** Max tile size a shared packer page can hold (same math as allocTile). */
    @:allow(ceramic.ImGuiVisualEntry)
    static function maxTileSize(isWidth:Bool):Int {
        var texSize = Std.int(2048 / screen.texturesDensity);
        var pad = isWidth ? PAD_WIDTH : PAD_HEIGHT;
        var padWithMargin = pad + MARGIN * 2;
        var cells = 0;
        var v = MARGIN;
        while (v + pad < texSize) {
            cells++;
            v += padWithMargin;
        }
        return cells * padWithMargin - MARGIN * 2;
    }

    /** Called by ImGuiSystem after ImGui.render(): sweep unused entries. */
    @:allow(ceramic.ImGuiSystem)
    static function endFrame():Void {

        var toRemove:Array<Visual> = null;

        for (visual => entry in entries) {
            if (entry.lastUsedFrame != currentFrame) {
                // Not displayed this frame: pause rendering, detach visual
                entry.detach();
                if (currentFrame - entry.lastUsedFrame > gracePeriodFrames) {
                    if (toRemove == null) toRemove = [];
                    toRemove.push(visual);
                }
            }
        }

        if (toRemove != null) {
            for (visual in toRemove) {
                var entry = entries.get(visual);
                entries.remove(visual);
                numEntries--;
                if (entry.dedicated) numDedicated--;
                entry.dispose(true);
            }
        }

        currentFrame++;

    }

    @:allow(ceramic.ImGuiVisualEntry)
    static function markDedicated(add:Bool):Void {
        numDedicated += add ? 1 : -1;
    }

}

/** One displayed visual: its filter (atlas tile or dedicated RT) + lifecycle state. */
@:allow(ceramic.ImGuiVisuals)
private class ImGuiVisualEntry {

    public var visual:Visual;

    public var filter:Filter = null;

    public var lastUsedFrame:Int = 0;

    /** Filter area size (logical units): the offscreen texture area. */
    public var width:Int = 0;
    public var height:Int = 0;

    /** Displayed image size in the ImGui layout (may differ from the
        texture area in native resolution mode). */
    public var displayWidth:Float = 0;
    public var displayHeight:Float = 0;

    /** True when this entry uses its own render texture instead of the shared atlas. */
    public var dedicated:Bool = false;

    /** Offscreen texture settings for this entry. */
    public var antialiasing:Int = 0;
    public var nearest:Bool = false;

    /** Invisible quad aligned with the ImGui item rect, used as the filter's
        `hitVisual` so ceramic pointer events reach the content. */
    public var hitProxy:Quad = null;

    /** Whether the ImGui window displaying this visual is focused (last submit). */
    public var windowFocused:Bool = false;

    /** Whether the displayed image is hovered (last submit). */
    public var hovered:Bool = false;

    var attached:Bool = false;

    public function new(visual:Visual) {
        this.visual = visual;
    }

    /** Create the filter if needed and keep its size/settings in sync. */
    public function ensureFilter(w:Int, h:Int, antialiasing:Int, nearest:Bool):Void {

        var needsDedicated = w > ImGuiVisuals.maxTileSize(true) || h > ImGuiVisuals.maxTileSize(false);

        if (filter != null && (needsDedicated != dedicated || antialiasing != this.antialiasing || nearest != this.nearest)) {
            // Atlas <-> dedicated switch, or texture settings change: rebuild the filter
            detach();
            if (dedicated) ImGuiVisuals.markDedicated(false);
            filter.destroy();
            filter = null;
            if (hitProxy != null) {
                hitProxy.destroy();
                hitProxy = null;
            }
            width = 0; // Force the size to be applied on the new filter
            height = 0;
        }

        if (filter == null) {
            filter = new Filter();
            if (!needsDedicated) {
                filter.textureTilePacker = ImGuiVisuals.packer(antialiasing, nearest);
            }
            else {
                filter.antialiasing = antialiasing;
                filter.textureFilter = nearest ? NEAREST : LINEAR;
                ImGuiVisuals.markDedicated(true);
            }
            dedicated = needsDedicated;
            this.antialiasing = antialiasing;
            this.nearest = nearest;
            filter.density = -1; // Follow screen.texturesDensity
            filter.touchable = false;
            // The filter quad itself must never draw on screen: only its
            // content -> render texture pass matters, display goes through
            // ImGui.image. (Parentless visuals are rendered in ceramic.)
            filter.transparent = true;

            hitProxy = new Quad();
            hitProxy.transparent = true; // Never drawn
            hitProxy.touchable = false;
            hitProxy.depth = 10000; // Wins pointer hits over scene visuals behind the UI
            filter.hitVisual = hitProxy; // Registers it as a hit visual redirecting to content
        }

        if (width != w || height != h) {
            width = w;
            height = h;
            filter.size(w, h);
        }

    }

    /** Reparent the visual into the filter content (elements semantics). */
    public function attach():Void {

        if (filter == null || visual == null || visual.destroyed)
            return;

        filter.active = true;

        if (!attached || visual.parent != filter.content) {
            if (visual.parent != null && visual.parent != filter.content) {
                visual.parent.remove(visual);
            }
            if (visual.parent != filter.content) {
                filter.content.add(visual);
            }
            visual.active = true;
            attached = true;
        }

    }

    /** Center the visual in the filter area (scaled to fit, or 1:1 in native resolution mode). */
    public function layoutContent(nativeResolution:Bool):Void {

        if (visual == null || visual.destroyed)
            return;

        var scale = 1.0;
        if (!nativeResolution && visual.width > 0 && visual.height > 0) {
            scale = Math.min(width / visual.width, height / visual.height);
        }
        visual.anchor(0.5, 0.5);
        visual.scale(scale, scale);
        visual.pos(width * 0.5, height * 0.5);

    }

    /** Pause: detach the visual and stop rendering (entry kept during grace period). */
    public function detach():Void {

        if (attached) {
            if (visual != null && !visual.destroyed && visual.parent == filter.content) {
                filter.content.remove(visual);
                visual.active = false;
            }
            attached = false;
        }
        if (filter != null) {
            filter.active = false;
            filter.touchable = false;
        }
        if (hitProxy != null) {
            hitProxy.touchable = false;
        }
        windowFocused = false;
        hovered = false;

    }

    /** Destroy the filter (releases the atlas tile). `detachVisual` false when the visual itself is being destroyed. */
    public function dispose(detachVisual:Bool):Void {

        if (detachVisual)
            detach();
        if (filter != null) {
            filter.destroy();
            filter = null;
        }
        if (hitProxy != null) {
            hitProxy.destroy();
            hitProxy = null;
        }
        visual = null;

    }

}

#end
