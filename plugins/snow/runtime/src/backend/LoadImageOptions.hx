package backend;

typedef LoadImageOptions = {

    /** Should pixels buffer be kept in memory (default: `false`) */
    @:optional var pixels:Bool;

    /** Should a texture be uploaded to GPU (default: `true`) */
    @:optional var texture:Bool;

} //LoadImageOptions
