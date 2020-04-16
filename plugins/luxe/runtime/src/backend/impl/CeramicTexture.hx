package backend.impl;

import luxe.options.ResourceOptions;

class CeramicTexture extends phoenix.Texture {

    public var ceramicId:String;

    public function new(ceramicId:String, _options:RenderTextureOptions) {

        this.ceramicId = ceramicId;

        super(_options);

    }

}
