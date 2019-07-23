package backend;

import phoenix.Texture;

abstract TextureId(phoenix.TextureID) from phoenix.TextureID to phoenix.TextureID {

    inline public static var DEFAULT:TextureId = (#if snow_web null #else 0 #end : phoenix.TextureID);

} //TextureId
