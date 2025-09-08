package ceramic;

enum abstract TilemapRenderType(Int) {

    /**
     * Does not render tiles at all.
     */
    var NONE = 0;

    /*
     * Uses individual quads to render the tilemap layer. Creates more
     * objects but allows to interact with each quads individually later.
     */
    var QUAD = 1;

    /*
     * Uses a single Mesh object to render all tiles instead of individual quads.
     * This improves memory usage and performance for large tilemaps.
     */
    var MESH = 2;

    public function toString() {

        final value:TilemapRenderType = abstract;
        return switch value {
            case NONE: 'NONE';
            case QUAD: 'QUAD';
            case MESH: 'MESH';
        }

    }

}
