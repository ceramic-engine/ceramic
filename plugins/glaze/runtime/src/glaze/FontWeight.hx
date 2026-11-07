// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The degree of blackness or stroke thickness of a font. This value ranges from 100.0 to 900.0,
 * with 400.0 as normal.
 */
abstract FontWeight(Float) from Float to Float {

    /** Thin weight (100), the thinnest value. */
    public static inline final THIN:FontWeight = 100.0;
    /** Extra light weight (200). */
    public static inline final EXTRA_LIGHT:FontWeight = 200.0;
    /** Light weight (300). */
    public static inline final LIGHT:FontWeight = 300.0;
    /** Normal (400). */
    public static inline final NORMAL:FontWeight = 400.0;
    /** Medium weight (500, higher than normal). */
    public static inline final MEDIUM:FontWeight = 500.0;
    /** Semibold weight (600). */
    public static inline final SEMIBOLD:FontWeight = 600.0;
    /** Bold weight (700). */
    public static inline final BOLD:FontWeight = 700.0;
    /** Extra-bold weight (800). */
    public static inline final EXTRA_BOLD:FontWeight = 800.0;
    /** Black weight (900), the thickest value. */
    public static inline final BLACK:FontWeight = 900.0;

}
