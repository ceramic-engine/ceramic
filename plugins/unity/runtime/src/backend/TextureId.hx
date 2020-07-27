package backend;

abstract TextureId(Int) from Int to Int {

    #if !debug inline #end public static var DEFAULT:TextureId = 0;

}
