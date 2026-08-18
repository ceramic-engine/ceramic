package backend;

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
    #if (!debug && !completion) inline #end public static var DEFAULT:TextureId = #if clay_web null #else untyped 0 #end;

    // NOTE: the old TextureId ↔ ImTextureID pointer-cast shim was removed with the
    // imgui plugin rework: ImTextureID values are now small registry keys managed by
    // ceramic.ImGuiTextures (cross-backend), never raw GPU handles.

}
