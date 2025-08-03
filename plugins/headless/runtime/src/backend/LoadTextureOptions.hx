package backend;

/**
 * Options for loading texture resources in the headless backend.
 * 
 * These options would typically control how textures are loaded,
 * processed, and stored. In headless mode, these options are
 * maintained for API compatibility but don't affect actual
 * texture loading since no image data is processed.
 * 
 * Currently, no specific options are defined, but the structure
 * allows for future expansion.
 */
typedef LoadTextureOptions = {
}
