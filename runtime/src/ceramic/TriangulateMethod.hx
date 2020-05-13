package ceramic;

enum TriangulateMethod {

    /**
     * Fast, but sometimes approximate
     */
    EARCUT;

    /**
     * A bit slower, usually more precise
     */
    POLY2TRI;

}