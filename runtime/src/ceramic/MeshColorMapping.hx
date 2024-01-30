package ceramic;

enum abstract MeshColorMapping(Int) {
    /**
     * Map a single color to the whole mesh.
     */
    var MESH = 0;
    /**
     * Map a color to each indice.
     */
    var INDICES = 1;
    /**
     * Map a color to each vertex.
     */
    var VERTICES = 2;
}
