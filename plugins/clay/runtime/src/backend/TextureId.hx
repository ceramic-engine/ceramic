package backend;

import clay.graphics.Graphics;

#if documentation
typedef TextureId = TextureIdClayImpl;
#end

abstract #if documentation TextureIdClayImpl(clay.Types.TextureId) #else TextureId(clay.Types.TextureId) #end from clay.Types.TextureId to clay.Types.TextureId {

    #if (!debug && !completion) inline #end public static var DEFAULT:TextureId = Graphics.NO_TEXTURE;

    #if (cpp && plugin_imgui)

    @:to public inline function toImTextureID():imguicpp.ImGui.ImTextureID {

        return untyped __cpp__('(void*)(long long){0}', this);

    }

    @:from public static inline function fromImTextureID(imTextureID:imguicpp.ImGui.ImTextureID) {

        var textureId:TextureId = untyped __cpp__('(int)(long long){0}', imTextureID);
        return textureId;

    }

    #end

}
