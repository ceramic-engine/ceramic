package ceramic;

#if plugin_imgui

import imgui.ImGui;

#if cpp
private typedef TDPtr = cpp.Star<ImTextureData>;
private typedef DDPtr = cpp.Star<ImDrawData>;
#elseif js
private typedef TDPtr = ImTextureData;
private typedef DDPtr = ImDrawData;
#elseif cs
private typedef TDPtr = ImTextureData;
private typedef DDPtr = ImDrawData;
#end

/**
 * Cross-backend texture bridge between Dear ImGui and ceramic.
 *
 * `ImTextureID` values are SMALL INTEGER KEYS into a registry of
 * `ceramic.Texture` instances - never raw GPU handles or pointers, so the
 * exact same convention works on every target (cpp, js/wasm, c#).
 *
 * Also implements the Dear ImGui 1.92 dynamic texture protocol
 * (`ImGuiBackendFlags_RendererHasTextures`): each frame, ImGui may request
 * texture creations/updates/destructions through `ImDrawData->Textures`
 * (font atlas pages etc.); `process()` fulfills them with ceramic textures.
 * Partial updates are collapsed into a full `submitPixels` (the only
 * cross-backend texture update path).
 */
class ImGuiTextures {

    /** id → texture. Index 0 is reserved (ImTextureID_Invalid == 0). */
    static var textures:Array<Texture> = [null];

    /** Textures created by the ImTextureData protocol (owned here). */
    static var owned:Map<Int, Bool> = new Map();

    /**
     * The `ImTextureID` for a ceramic texture - use it with `ImGui.image()`
     * etc. Registers the texture on first use; the slot is released
     * automatically when the texture is destroyed.
     */
    public static function textureId(texture:Texture):ImTextureID {

        if (texture == null || texture.destroyed) return cast 0;

        for (i in 1...textures.length) {
            if (textures[i] == texture) return cast i;
        }

        var id = allocSlot(texture);
        texture.onDestroy(null, _ -> release(id));
        return cast id;

    }

    /**
     * An `ImTextureRef` for a ceramic texture - this is what `ImGui.image()`,
     * `ImGui.imageButton()` etc. take as first argument.
     */
    public static function textureRef(texture:Texture):ImTextureRef {

        return ImTextureRef.fromID(textureId(texture));

    }

    /** The ceramic texture for an `ImTextureID` key (null if unknown). */
    public static function texture(id:ImTextureID):Texture {

        var i:Int = cast id;
        if (i <= 0 || i >= textures.length) return null;
        return textures[i];

    }

    /** Every registered texture (for `Renderable.computeUsedTextures`). */
    public static function allTextures():Array<Texture> {
        return [for (t in textures) if (t != null && !t.destroyed) t];
    }

    static function allocSlot(texture:Texture):Int {
        for (i in 1...textures.length) {
            if (textures[i] == null) { textures[i] = texture; return i; }
        }
        textures.push(texture);
        return textures.length - 1;
    }

    static function release(id:Int):Void {
        if (id > 0 && id < textures.length) {
            textures[id] = null;
            owned.remove(id);
        }
    }

    /**
     * Fulfill this frame's ImTextureData requests (called by the renderable,
     * right before walking the draw lists).
     */
    public static function process(drawData:DDPtr):Void {

        var texVec = drawData.textures;
        #if cpp
        if (texVec == null) return;
        var count:Int = texVec.size;
        var data:cpp.RawPointer<cpp.Star<ImTextureData>> = cast texVec.data;
        #elseif js
        if ((texVec:Int) == 0) return;
        var count:Int = texVec.size;
        var data:Int = texVec.data;
        #elseif cs
        if ((texVec:Float) == 0) return;
        var count:Int = texVec.size;
        var data:Float = texVec.data;
        #end

        for (i in 0...count) {
            #if cpp
            var td:TDPtr = data[i];
            #elseif js
            var td:TDPtr = imguijs.ImGuiJs.getU32(data + (i << 2));
            #elseif cs
            var td:TDPtr = imguics.ImGuiCs.readPtr(data + i * imguics.ImGuiCs.ptrSize);
            #end
            var status = td.status;

            if (status == ImTextureStatus.WantCreate) {
                var tex = createFromTextureData(td);
                if (tex != null) {
                    var id = allocSlot(tex);
                    owned.set(id, true);
                    ImTextureData.setTexID(td, cast id);
                    ImTextureData.setStatus(td, ImTextureStatus.OK);
                }
            }
            else if (status == ImTextureStatus.WantUpdates) {
                // Cross-backend path: re-upload the WHOLE texture (no sub-rect
                // update exists on every backend). Fine for atlas-sized textures
                // at the frequency ImGui updates them.
                var id:Int = cast td.texID;
                var tex = texture(cast id);
                if (tex != null) {
                    tex.submitPixels(pixelsFromTextureData(td));
                }
                ImTextureData.setStatus(td, ImTextureStatus.OK);
            }
            else if (status == ImTextureStatus.WantDestroy && td.unusedFrames > 0) {
                var id:Int = cast td.texID;
                var tex = texture(cast id);
                if (tex != null && owned.exists(id)) {
                    release(id);
                    tex.destroy();
                }
                ImTextureData.setTexID(td, cast 0);
                ImTextureData.setStatus(td, ImTextureStatus.Destroyed);
            }
        }

    }

    static function createFromTextureData(td:TDPtr):Texture {

        var pixels = pixelsFromTextureData(td);
        if (pixels == null) return null;
        var tex = Texture.fromPixels(td.width, td.height, pixels, 1);
        tex.filter = LINEAR;
        return tex;

    }

    /**
     * Copy the RGBA pixels out of an ImTextureData, PREMULTIPLYING alpha
     * (ceramic's whole pipeline is premultiplied; ImGui atlases are straight
     * alpha - uploading them raw makes empty texels add pure white with our
     * ONE / ONE_MINUS_SRC_ALPHA blending). Converts Alpha8 when needed.
     */
    static function pixelsFromTextureData(td:TDPtr):UInt8Array {

        var w:Int = td.width;
        var h:Int = td.height;
        #if cpp
        var raw:cpp.RawPointer<cpp.UInt8> = cast ImTextureData.getPixels(td);
        if (raw == null) return null;
        #elseif js
        var rawAddr:Int = ImTextureData.getPixels(td);
        if (rawAddr == 0) return null;
        var raw:Dynamic = imguijs.ImGuiJs.M.HEAPU8.subarray(rawAddr, rawAddr + w * h * 4);
        #elseif cs
        var rawAddr:Float = ImTextureData.getPixels(td);
        if (rawAddr == 0) return null;
        #end

        var out = new UInt8Array(w * h * 4);
        var n = w * h;
        #if cs
        inline function raw(i:Int):Int return imguics.ImGuiCs.getU8(rawAddr + i);
        if (td.format == ImTextureFormat.RGBA32) {
            for (i in 0...n) {
                var a:Int = raw(i * 4 + 3);
                out[i * 4] = Std.int(raw(i * 4) * a / 255);
                out[i * 4 + 1] = Std.int(raw(i * 4 + 1) * a / 255);
                out[i * 4 + 2] = Std.int(raw(i * 4 + 2) * a / 255);
                out[i * 4 + 3] = a;
            }
        }
        else {
            for (i in 0...n) {
                var a:Int = raw(i);
                out[i * 4] = a;
                out[i * 4 + 1] = a;
                out[i * 4 + 2] = a;
                out[i * 4 + 3] = a;
            }
        }
        return out;
        #else
        if (td.format == ImTextureFormat.RGBA32) {
            for (i in 0...n) {
                var a:Int = raw[i * 4 + 3];
                out[i * 4] = Std.int(raw[i * 4] * a / 255);
                out[i * 4 + 1] = Std.int(raw[i * 4 + 1] * a / 255);
                out[i * 4 + 2] = Std.int(raw[i * 4 + 2] * a / 255);
                out[i * 4 + 3] = a;
            }
        }
        else {
            // Alpha8 → premultiplied white RGBA
            for (i in 0...n) {
                var a:Int = raw[i];
                out[i * 4] = a;
                out[i * 4 + 1] = a;
                out[i * 4 + 2] = a;
                out[i * 4 + 3] = a;
            }
        }
        return out;
        #end

    }

}

#end
