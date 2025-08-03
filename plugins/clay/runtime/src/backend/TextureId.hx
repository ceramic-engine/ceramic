package backend;

import clay.graphics.Graphics;

/**
 * Represents a GPU texture identifier in the Clay backend.
 * 
 * TextureId is a lightweight handle that references a texture resource
 * on the GPU. It's used internally by the rendering system to bind
 * textures for drawing operations.
 * 
 * This abstract type provides:
 * - Type-safe texture references
 * - Default "no texture" constant
 * - ImGui integration for texture display in debug UI
 * 
 * The actual value is typically an OpenGL texture handle or similar
 * GPU-specific identifier.
 */
#if documentation
typedef TextureId = TextureIdClayImpl;
#end

abstract #if documentation TextureIdClayImpl(clay.Types.TextureId) #else TextureId(clay.Types.TextureId) #end from clay.Types.TextureId to clay.Types.TextureId {

    /**
     * Default texture ID representing "no texture".
     * Used when rendering without textures (solid colors only).
     */
    #if (!debug && !completion) inline #end public static var DEFAULT:TextureId = Graphics.NO_TEXTURE;

    #if (cpp && plugin_imgui)

    /**
     * Converts this TextureId to ImGui's texture ID format.
     * Allows textures to be displayed in ImGui windows and widgets.
     * 
     * @return ImGui-compatible texture identifier
     */
    @:to public inline function toImTextureID():imguicpp.ImGui.ImTextureID {

        return untyped __cpp__('(void*)(long long){0}', this);

    }

    /**
     * Creates a TextureId from an ImGui texture identifier.
     * Allows ImGui-managed textures to be used in Ceramic rendering.
     * 
     * @param imTextureID ImGui texture identifier
     * @return Ceramic-compatible TextureId
     */
    @:from public static inline function fromImTextureID(imTextureID:imguicpp.ImGui.ImTextureID) {

        var textureId:TextureId = untyped __cpp__('(int)(long long){0}', imTextureID);
        return textureId;

    }

    #end

}
