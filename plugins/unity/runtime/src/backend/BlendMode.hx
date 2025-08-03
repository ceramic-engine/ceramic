package backend;

#if !no_backend_docs
/**
 * Blend mode factors for GPU rendering operations.
 * 
 * These values correspond to OpenGL/Unity blend factors used when
 * combining source (new) and destination (existing) pixel colors.
 * The blend equation combines these factors to produce the final color:
 * 
 * FinalColor = (SourceColor * SourceFactor) + (DestColor * DestFactor)
 * 
 * Common blend mode combinations:
 * - Normal alpha blending: src=SRC_ALPHA, dst=ONE_MINUS_SRC_ALPHA
 * - Additive blending: src=ONE, dst=ONE
 * - Multiply blending: src=DST_COLOR, dst=ZERO
 * - Premultiplied alpha: src=ONE, dst=ONE_MINUS_SRC_ALPHA
 * 
 * @see backend.Draw Uses these for configuring blend states
 * @see ceramic.Blending Higher-level blending mode abstraction
 */
#end
#if documentation

typedef BlendMode = BlendModeImpl;

enum abstract BlendModeImpl(Int) from Int to Int {

    #if !no_backend_docs
    /**
     * Factor is (0, 0, 0, 0).
     * Completely removes this component from the blend equation.
     */
    #end
    var ZERO                    = 0;
    
    #if !no_backend_docs
    /**
     * Factor is (1, 1, 1, 1).
     * Uses the full color/alpha values without modification.
     */
    #end
    var ONE                     = 1;
    
    #if !no_backend_docs
    /**
     * Factor is (Rs, Gs, Bs, As) from source.
     * Multiplies by the source color components.
     */
    #end
    var SRC_COLOR               = 2;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Rs, 1-Gs, 1-Bs, 1-As) from source.
     * Multiplies by the inverse of source color components.
     */
    #end
    var ONE_MINUS_SRC_COLOR     = 3;
    
    #if !no_backend_docs
    /**
     * Factor is (As, As, As, As) from source.
     * Multiplies all components by source alpha.
     * Most common for standard alpha blending.
     */
    #end
    var SRC_ALPHA               = 4;
    
    #if !no_backend_docs
    /**
     * Factor is (1-As, 1-As, 1-As, 1-As) from source.
     * Multiplies all components by inverse of source alpha.
     * Most common for destination in alpha blending.
     */
    #end
    var ONE_MINUS_SRC_ALPHA     = 5;
    
    #if !no_backend_docs
    /**
     * Factor is (Ad, Ad, Ad, Ad) from destination.
     * Multiplies all components by destination alpha.
     */
    #end
    var DST_ALPHA               = 6;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Ad, 1-Ad, 1-Ad, 1-Ad) from destination.
     * Multiplies all components by inverse of destination alpha.
     */
    #end
    var ONE_MINUS_DST_ALPHA     = 7;
    
    #if !no_backend_docs
    /**
     * Factor is (Rd, Gd, Bd, Ad) from destination.
     * Multiplies by the destination color components.
     */
    #end
    var DST_COLOR               = 8;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Rd, 1-Gd, 1-Bd, 1-Ad) from destination.
     * Multiplies by the inverse of destination color components.
     */
    #end
    var ONE_MINUS_DST_COLOR     = 9;
    
    #if !no_backend_docs
    /**
     * Factor is (f, f, f, 1) where f = min(As, 1-Ad).
     * Useful for certain advanced blending techniques.
     */
    #end
    var SRC_ALPHA_SATURATE      = 10;

}

#else

enum abstract BlendMode(Int) from Int to Int {

    #if !no_backend_docs
    /**
     * Factor is (0, 0, 0, 0).
     * Completely removes this component from the blend equation.
     */
    #end
    var ZERO                    = 0;
    
    #if !no_backend_docs
    /**
     * Factor is (1, 1, 1, 1).
     * Uses the full color/alpha values without modification.
     */
    #end
    var ONE                     = 1;
    
    #if !no_backend_docs
    /**
     * Factor is (Rs, Gs, Bs, As) from source.
     * Multiplies by the source color components.
     */
    #end
    var SRC_COLOR               = 2;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Rs, 1-Gs, 1-Bs, 1-As) from source.
     * Multiplies by the inverse of source color components.
     */
    #end
    var ONE_MINUS_SRC_COLOR     = 3;
    
    #if !no_backend_docs
    /**
     * Factor is (As, As, As, As) from source.
     * Multiplies all components by source alpha.
     * Most common for standard alpha blending.
     */
    #end
    var SRC_ALPHA               = 4;
    
    #if !no_backend_docs
    /**
     * Factor is (1-As, 1-As, 1-As, 1-As) from source.
     * Multiplies all components by inverse of source alpha.
     * Most common for destination in alpha blending.
     */
    #end
    var ONE_MINUS_SRC_ALPHA     = 5;
    
    #if !no_backend_docs
    /**
     * Factor is (Ad, Ad, Ad, Ad) from destination.
     * Multiplies all components by destination alpha.
     */
    #end
    var DST_ALPHA               = 6;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Ad, 1-Ad, 1-Ad, 1-Ad) from destination.
     * Multiplies all components by inverse of destination alpha.
     */
    #end
    var ONE_MINUS_DST_ALPHA     = 7;
    
    #if !no_backend_docs
    /**
     * Factor is (Rd, Gd, Bd, Ad) from destination.
     * Multiplies by the destination color components.
     */
    #end
    var DST_COLOR               = 8;
    
    #if !no_backend_docs
    /**
     * Factor is (1-Rd, 1-Gd, 1-Bd, 1-Ad) from destination.
     * Multiplies by the inverse of destination color components.
     */
    #end
    var ONE_MINUS_DST_COLOR     = 9;
    
    #if !no_backend_docs
    /**
     * Factor is (f, f, f, 1) where f = min(As, 1-Ad).
     * Useful for certain advanced blending techniques.
     */
    #end
    var SRC_ALPHA_SATURATE      = 10;

}

#end
