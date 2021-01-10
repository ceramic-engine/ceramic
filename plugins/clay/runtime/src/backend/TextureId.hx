package backend;

import clay.graphics.Graphics;

abstract TextureId(clay.Types.TextureId) from clay.Types.TextureId to clay.Types.TextureId {

    #if !debug inline #end public static var DEFAULT:TextureId = Graphics.NO_TEXTURE;

}
