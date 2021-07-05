package backend;

typedef TextureId = TextureIdImpl;

abstract TextureIdImpl(Int) from Int to Int {

    #if !debug inline #end public static var DEFAULT:TextureId = 0;

}
