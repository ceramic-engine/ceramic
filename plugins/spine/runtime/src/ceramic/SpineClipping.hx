package ceramic;

/**
 * How a `Spine` visual renders the clipping attachments of its skeleton.
 *
 * @see Spine.clipping
 */
enum SpineClipping {

    /**
     * The geometry is clipped on the CPU by the spine runtime, as official
     * renderers do. Works inside a visual that is itself clipped (with `clip`),
     * does not break draw batching and supports inverse clipping.
     * Not available with the legacy runtime (`spine_legacy`).
     */
    SOFTWARE;

    /**
     * The geometry is clipped by the GPU with the stencil buffer. No CPU cost per
     * clipped triangle, but a clipped slot ignores the `clip` of its parents,
     * and each clipped slot breaks draw batching.
     */
    STENCIL;

}
