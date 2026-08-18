package ceramic;

#if plugin_imgui

import ceramic.Shortcuts.*;
import imgui.ImGui;

/**
 * Renders Dear ImGui's draw data THROUGH ceramic's own 2D pipeline - no
 * imgui_impl_* platform renderer involved, which is what makes the plugin
 * cross-backend (clay native, clay web, unity share this exact code).
 *
 * A `Renderable` gets the concrete `backend.Draw` in `render()`: ImGui's
 * per-command model (scissor rect + texture + a vertex/index slice) maps 1:1
 * onto `enableScissor` / `bindTexture` / `putPos...` / `flush`. The engine's
 * `drawRenderable` bracket flushes and dirties the 2D state afterwards, so the
 * regular pipeline resumes untouched.
 *
 * Coordinates are logical (ImGui's `DisplaySize` is ceramic's logical screen
 * size; the backend applies density to both geometry and scissor). Vertex
 * colors are premultiplied CPU-side to match ceramic's premultiplied-alpha
 * compositing.
 */
class ImGuiRenderable extends Renderable {

    public function new() {

        super();
        depth = 10000; // above everything by default (configurable)

    }

    override function computeUsedTextures():Void {

        var arr = usedTextures.original;
        arr.resize(0);
        for (tex in ImGuiTextures.allTextures()) {
            arr.push(tex);
        }

    }

    override function render(draw:backend.Draw):Void {

        #if (!cpp && !js && !cs)
        return;
        #else

        var drawData = ImGui.getDrawData();
        #if cpp
        if (drawData == null || !drawData.valid) return;
        #elseif js
        if ((drawData:Int) == 0 || !drawData.valid) return;
        #elseif cs
        if ((drawData:Float) == 0 || !drawData.valid) return;
        #end

        // Fulfill this frame's dynamic texture requests (font atlas pages...).
        ImGuiTextures.process(drawData);

        if (drawData.cmdListsCount <= 0) return;

        // Renderer state: ceramic's default textured shader (texture × vertex
        // color, exactly ImGui's model) + premultiplied-alpha blending.
        var shader = ceramic.App.app.defaultTexturedShader;
        if (shader == null) return;
        var backendShader = shader.backendItem;
        var multiTexture = ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(backendShader);

        draw.useShader(backendShader);
        draw.setBlendFuncSeparate(
            backend.BlendMode.ONE, backend.BlendMode.ONE_MINUS_SRC_ALPHA,
            backend.BlendMode.ONE, backend.BlendMode.ONE_MINUS_SRC_ALPHA
        );

        var displayPosX:Float = drawData.displayPos.x;
        var displayPosY:Float = drawData.displayPos.y;

        #if cpp
        var lists:cpp.RawPointer<cpp.Star<ImDrawList>> = cast drawData.cmdLists.data;
        #elseif js
        var lists:Int = drawData.cmdLists.data;
        var cmdSize:Int = ImDrawCmd.sizeOf();
        var vertSize:Int = ImDrawVert.sizeOf();
        #elseif cs
        var lists:Float = drawData.cmdLists.data;
        var cmdSize:Int = ImDrawCmd.sizeOf();
        var vertSize:Int = ImDrawVert.sizeOf();
        #end
        var listCount:Int = drawData.cmdListsCount;

        var boundTexture:Texture = null;

        for (li in 0...listCount) {
            #if cpp
            var list:cpp.Star<ImDrawList> = lists[li];
            var vtx:cpp.RawPointer<ImDrawVert> = cast list.vtxBuffer.data;
            var idx:cpp.RawPointer<cpp.UInt16> = cast list.idxBuffer.data;
            var cmdCount:Int = list.cmdBuffer.size;
            var cmds:cpp.RawPointer<ImDrawCmd> = cast list.cmdBuffer.data;
            #elseif js
            var list:ImDrawList = imguijs.ImGuiJs.getU32(lists + (li << 2));
            var vtx:Int = (list.vtxBuffer.data:Int);
            var idx:Int = (list.idxBuffer.data:Int);
            var cmdCount:Int = list.cmdBuffer.size;
            var cmds:Int = (list.cmdBuffer.data:Int);
            #elseif cs
            var list:ImDrawList = imguics.ImGuiCs.readPtr(lists + li * imguics.ImGuiCs.ptrSize);
            var vtx:Float = (list.vtxBuffer.data:Float);
            var idx:Float = (list.idxBuffer.data:Float);
            var cmdCount:Int = list.cmdBuffer.size;
            var cmds:Float = (list.cmdBuffer.data:Float);
            #end

            for (ci in 0...cmdCount) {
                #if cpp
                var imCmd:ImDrawCmd = cmds[ci];
                #else
                var imCmd:ImDrawCmd = cmds + ci * cmdSize;
                #end
                var elemCount:Int = imCmd.elemCount;
                if (elemCount == 0) continue;
                #if cpp
                if (imCmd.userCallback != null) continue; // callbacks unsupported
                #else
                if (imCmd.userCallback != 0) continue; // callbacks unsupported
                #end

                // Resolve the command's texture through the registry
                // (== ImTextureRef::GetTexID(), done field-wise to stay simple).
                var texRef:ImTextureRef = imCmd.texRef;
                #if cpp
                var texId:Int = texRef._TexData != null
                    ? cast texRef._TexData.texID
                    : cast texRef._TexID;
                #elseif js
                var texId:Int = texRef._TexData != 0
                    ? Std.int((texRef._TexData:ImTextureData).texID)
                    : Std.int(texRef._TexID);
                #elseif cs
                var texId:Int = !imguics.ImGuiCs.isNull(texRef._TexData)
                    ? Std.int((imguics.ImGuiCs.addr(texRef._TexData):ImTextureData).texID)
                    : Std.int(imguics.ImGuiCs.from64(texRef._TexID));
                #end
                var tex = ImGuiTextures.texture(cast texId);
                if (tex == null || tex.destroyed) continue;

                // Per-command scissor (logical coordinates).
                var clip:ImVec4 = imCmd.clipRect;
                var clipX:Float = clip.x - displayPosX;
                var clipY:Float = clip.y - displayPosY;
                var clipW:Float = (clip.z - displayPosX) - clipX;
                var clipH:Float = (clip.w - displayPosY) - clipY;
                if (clipW <= 0 || clipH <= 0) continue;

                draw.flush();

                if (tex != boundTexture) {
                    boundTexture = tex;
                    draw.setActiveTexture(0);
                    draw.bindTexture(tex.backendItem);
                }

                draw.enableScissor(clipX, clipY, clipW, clipH);

                #if (js || cs)
                pushCommand(draw, multiTexture, vtx, idx, vertSize,
                    imCmd.vtxOffset, imCmd.idxOffset, elemCount);
                #else
                pushCommand(draw, multiTexture, vtx, idx,
                    imCmd.vtxOffset, imCmd.idxOffset, elemCount);
                #end

                draw.flush();
                draw.disableScissor();
            }
        }

        #end

    }

    /**
     * Push one draw command's geometry. The command's indices reference a
     * window of the list's vertex buffer: we locate that [min..max] window,
     * push those vertices once, and rebase the indices. Windows larger than
     * the batcher's capacity fall back to per-triangle pushes.
     */
    #if cpp
    function pushCommand(draw:backend.Draw, multiTexture:Bool,
        vtx:cpp.RawPointer<ImDrawVert>, idx:cpp.RawPointer<cpp.UInt16>,
        vtxOffset:Int, idxOffset:Int, elemCount:Int):Void {

        // Locate the vertex window used by this command.
        var minV = 0x3FFFFFFF;
        var maxV = -1;
        for (i in 0...elemCount) {
            var v:Int = idx[idxOffset + i] + vtxOffset;
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
        }
        if (maxV < minV) return;
        var windowSize = maxV - minV + 1;

        if (!draw.shouldFlush(windowSize, elemCount, 0)) {
            // Fast path: whole window fits in one batch.
            var base = draw.getNumPos();
            for (v in minV...maxV + 1) {
                putVertex(draw, multiTexture, vtx, v);
            }
            for (i in 0...elemCount) {
                draw.putIndice(base + (idx[idxOffset + i] + vtxOffset - minV));
            }
        }
        else {
            // Slow path (huge command): triangle by triangle, duplicating vertices.
            var i = 0;
            while (i < elemCount) {
                if (draw.shouldFlush(3, 3, 0)) draw.flush();
                var base = draw.getNumPos();
                for (k in 0...3) {
                    putVertex(draw, multiTexture, vtx, idx[idxOffset + i + k] + vtxOffset);
                    draw.putIndice(base + k);
                }
                i += 3;
            }
        }

    }

    inline function putVertex(draw:backend.Draw, multiTexture:Bool,
        vtx:cpp.RawPointer<ImDrawVert>, v:Int):Void {

        var vert:ImDrawVert = vtx[v];
        var px:Float = vert.pos.x;
        var py:Float = vert.pos.y;
        var ux:Float = vert.uv.x;
        var uy:Float = vert.uv.y;
        var col:Int = cast vert.col;

        // IM_COL32: R | G<<8 | B<<16 | A<<24 → premultiplied floats.
        var a = ((col >>> 24) & 0xFF) / 255.0;
        var r = ((col) & 0xFF) / 255.0 * a;
        var g = ((col >>> 8) & 0xFF) / 255.0 * a;
        var b = ((col >>> 16) & 0xFF) / 255.0 * a;

        if (multiTexture) {
            draw.putPosAndTextureSlot(px, py, 0, 0);
        }
        else {
            draw.putPos(px, py, 0);
        }
        draw.putUVs(ux, uy);
        draw.putColor(r, g, b, a);

    }
    #end

    #if (js || cs)
    #if js
    static inline function heapU16(a:Int):Int return imguijs.ImGuiJs.getU16(a);
    static inline function heapF32(a:Int):Float return imguijs.ImGuiJs.getF32(a);
    static inline function heapU32(a:Int):Int return imguijs.ImGuiJs.getU32(a);
    #elseif cs
    static inline function heapU16(a:Float):Int return imguics.ImGuiCs.getU16(a);
    static inline function heapF32(a:Float):Float return imguics.ImGuiCs.getF32(a);
    static inline function heapU32(a:Float):Int return Std.int(imguics.ImGuiCs.getU32(a));
    #end

    function pushCommand(draw:backend.Draw, multiTexture:Bool,
        vtx:#if js Int #else Float #end, idx:#if js Int #else Float #end, vertSize:Int,
        vtxOffset:Int, idxOffset:Int, elemCount:Int):Void {

        // Locate the vertex window used by this command.
        var minV = 0x3FFFFFFF;
        var maxV = -1;
        for (i in 0...elemCount) {
            var v:Int = heapU16(idx + ((idxOffset + i) << 1)) + vtxOffset;
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
        }
        if (maxV < minV) return;
        var windowSize = maxV - minV + 1;

        if (!draw.shouldFlush(windowSize, elemCount, 0)) {
            var base = draw.getNumPos();
            for (v in minV...maxV + 1) {
                putVertex(draw, multiTexture, vtx + v * vertSize);
            }
            for (i in 0...elemCount) {
                draw.putIndice(base + (heapU16(idx + ((idxOffset + i) << 1)) + vtxOffset - minV));
            }
        }
        else {
            var i = 0;
            while (i < elemCount) {
                if (draw.shouldFlush(3, 3, 0)) draw.flush();
                var base = draw.getNumPos();
                for (k in 0...3) {
                    var v:Int = heapU16(idx + ((idxOffset + i + k) << 1)) + vtxOffset;
                    putVertex(draw, multiTexture, vtx + v * vertSize);
                    draw.putIndice(base + k);
                }
                i += 3;
            }
        }

    }

    inline function putVertex(draw:backend.Draw, multiTexture:Bool, vertAddr:#if js Int #else Float #end):Void {

        // ImDrawVert: pos (f32 x2) @0, uv (f32 x2) @8, col (u32 IM_COL32) @16
        var px:Float = heapF32(vertAddr);
        var py:Float = heapF32(vertAddr + 4);
        var ux:Float = heapF32(vertAddr + 8);
        var uy:Float = heapF32(vertAddr + 12);
        var col:Int = heapU32(vertAddr + 16);

        var a = ((col >>> 24) & 0xFF) / 255.0;
        var r = ((col) & 0xFF) / 255.0 * a;
        var g = ((col >>> 8) & 0xFF) / 255.0 * a;
        var b = ((col >>> 16) & 0xFF) / 255.0 * a;

        if (multiTexture) {
            draw.putPosAndTextureSlot(px, py, 0, 0);
        }
        else {
            draw.putPos(px, py, 0);
        }
        draw.putUVs(ux, uy);
        draw.putColor(r, g, b, a);

    }
    #end

}

#end
