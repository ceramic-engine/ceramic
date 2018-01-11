package backend;

import ceramic.TextureFilter;

import snow.types.Types;
import snow.modules.opengl.GL;

class TextureImpl {

    static var maxSize:Int = GL.getParameter(GL.MAX_TEXTURE_SIZE);

/// Public properties

    public var image:Image = null;

    public var width:Int = 0;

    public var height:Int = 0;

    public var widthActual:Int = 0;

    public var heightActual:Int = 0;

    public var filter:TextureFilter = LINEAR;

/// Internal

    var glTexture:GLTexture;

    public function new(width:Int = 0, height:Int = 0) {

        this.width = width;
        this.height = height;

    } //new

    public function fromAsset(asset:AssetImage, clearAsset:Bool = true):Void {

        clear();

        glTexture = GL.createTexture();

        width = asset.image.width;
        height = asset.image.height;
        widthActual = asset.image.width_actual;
        heightActual = asset.image.height_actual;

        submit(asset.image.pixels);

        if (clearAsset) {
            asset.image.pixels = null;
        }

        applyProps();

    } //fromAsset

    /** Submit a pixels array to the GL texture. Must match the type and format accordingly. */
    public function submit(pixels:snow.api.buffers.Uint8Array):Void {

        var buffer:snow.api.buffers.ArrayBufferView = pixels;

        GL.texImage2D(
            GL.TEXTURE_2D,
            0,
            GL.RGBA,
            widthActual,
            heightActual,
            0,
            GL.RGBA,
            GL.UNSIGNED_BYTE,
            buffer
        );

    } //submit

    public function clear():Void {

        if (glTexture != null) {
            GL.deleteTexture(glTexture);
        }

    } //clear

/// Internal

    inline function applyProps():Void {

        var glFilter = filter == NEAREST ? GL.NEAREST : GL.LINEAR;

        GL.texParameteri(
            GL.TEXTURE_2D,
            GL.TEXTURE_MIN_FILTER,
            glFilter
        );

        GL.texParameteri(
            GL.TEXTURE_2D,
            GL.TEXTURE_MAG_FILTER,
            glFilter
        );

        GL.texParameteri(
            GL.TEXTURE_2D,
            GL.TEXTURE_WRAP_S,
            GL.CLAMP_TO_EDGE
        );

        GL.texParameteri(
            GL.TEXTURE_2D,
            GL.TEXTURE_WRAP_T,
            GL.CLAMP_TO_EDGE
        );

    } //applyProps

} //TextureImpl
