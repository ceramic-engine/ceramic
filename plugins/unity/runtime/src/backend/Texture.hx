package backend;

#if documentation

typedef Texture = TextureImpl;

#else

abstract Texture(TextureImpl) from TextureImpl to TextureImpl {}

#end
