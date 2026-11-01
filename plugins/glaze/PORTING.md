# Porting conventions (Rust to Haxe)

Rules shared by every port in this project: GPUI itself (`runtime/src/gpui`), gpui-kit later, and the pure Haxe libraries written in `ceramic/git/` (plutovg, lunasvg, taffy...). The goal is code that can be compared line by line with the Rust (or C / C++) source, while staying idiomatic Haxe and fast on hxcpp.

## Sources and files

- Reference sources: `gpui-src/gpui-pre-0.3.10/src` (GPUI), `gpui-src/gpui-pre-wgpu-0.3.10/src` (renderer and shaders), `gpui-kit/crates/*` (gpui-kit).
- One Haxe module per main type. A Rust file `src/foo/bar_baz.rs` defining `BarBaz` becomes `gpui/foo/BarBaz.hx`. Small helper types closely tied to the main one can live in the same module.
- Every ported file starts with a header naming its origin, the original copyright and license, and stating that the file was modified (required by Apache-2.0, section 4):

  ```haxe
  // Ported from gpui-pre 0.3.10: src/geometry.rs
  // Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
  // Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
  ```

  When a module gathers parts of several Rust files, list them all. Code that GPUI itself took from elsewhere keeps that credit too (e.g. the Windows Terminal gamma correction, MIT).
- Keep doc comments, shortened when they only repeat the code. Drop Rust-only examples.

## Naming

- camelCase, converted mechanically: `h_flex` → `hFlex`, `gap_2` → `gap2`, `on_mouse_down` → `onMouseDown`, `px_0p5` → `px0p5`, `is_empty` → `isEmpty`.
- Types keep their Rust name (`Bounds`, `ScaledPixels`, `LineLayout`).
- Rust enum variants become Haxe enum constructors with the same name (`Axis.Horizontal`).
- Constants: `UPPER_SNAKE_CASE`, as in Rust.
- When a name collides with a Haxe keyword or an inherited Ceramic member, add a suffix and say so in a comment (`function new` cannot be used for a static factory: use `of`, `create` or keep a free function in `Prelude`).

## Free functions

Rust free functions used everywhere (`px`, `rems`, `relative`, `point`, `size`, `bounds`, `div`, `rgb`, `hsla`...) are static functions of `gpui.Prelude`, used with `import gpui.Prelude.*;`.

## Types

| Rust | Haxe |
|---|---|
| `f32`, `f64` | `Float` |
| `i32`, `u32`, `usize`, `u8`... | `Int` (watch overflow and sign on `u32` / `u64` math) |
| `bool` | `Bool` |
| `String`, `&str`, `SharedString` | `String` |
| `Option<T>` | `Null<T>` |
| `Result<T, E>` | return value plus exception, or a dedicated enum when the error is part of normal flow |
| `Vec<T>`, `SmallVec`, slices | `Array<T>` |
| `HashMap`, `BTreeMap` | `Map`, or a sorted `Array` when order matters |
| `Rc<T>`, `Arc<T>`, `Box<T>` | plain reference |
| `RefCell`, `Cell`, `Mutex` | plain mutable field |
| closures | Haxe functions |
| traits | interfaces, or abstract base classes when they carry default methods |
| enums with data | Haxe `enum` |
| structs | classes (`@:structInit` where it helps construction) |
| `impl Default` | default values in constructor arguments or a static `defaultValue()` |

## Units and geometry

- Units are abstracts with implicit conversions, so they mostly document intent:
  - `abstract Pixels(Float) from Float to Float`, same for `ScaledPixels`, `Rems`, `Radians`, `Percentage`;
  - `abstract DevicePixels(Int) from Int to Int`.
- Numeric geometry types are **concrete classes over Float**, not generic: `Point`, `Size`, `Bounds`, `Edges`, `Corners`. They stand for `Point<Pixels>`, `Point<ScaledPixels>`, `Point<f32>` and `Point<DevicePixels>` alike (device values are stored as whole Floats). Rationale: Haxe has no trait-bound arithmetic, and a generic `T` field compiles to `Dynamic` (boxed) on hxcpp.
- When Rust instantiates them with a non-numeric type (`Size<Length>`, `Edges<AbsoluteLength>`, `Size<AvailableSpace>`, `Corners<Option<...>>`), use the generic variants `PointOf<T>`, `SizeOf<T>`, `BoundsOf<T>`, `EdgesOf<T>`, `CornersOf<T>`.
- Geometry objects are **immutable** (`final` fields) and have value semantics: every operation returns a new instance. Rust code that mutates a field in place (`bounds.origin.x += dx`) becomes a new object. Constructors are `inline` so that local temporaries can be optimized away.
- Structural equality: `a.equals(b)` (never `==`, which compares references).

## Strings and text indices

- GPUI and gpui-kit use **UTF-8 byte offsets** for text ranges. We keep that convention everywhere (`TextRun.len`, ranges, selections), and convert at the boundaries only (Haxe string indices, UTF-16 for IME).
- Use the helpers of `gpui.util.Utf8` (to be written with the text system) instead of `String.length` / `charAt` on text that may contain non-ASCII characters.

## Reactivity

- Entity state that is read during render is a `gpui.Model` with `@observe` fields (tracker). See the tracker principles in [CERAMIC_GPUI_PLAN_1.md](CERAMIC_GPUI_PLAN_1.md).
- `cx.notify()` stays available for state that is not observable.

## Performance (hxcpp first)

- Avoid `Dynamic`, `Reflect` and anonymous structures in hot paths.
- No per-frame closures where an existing object can be reused.
- Prefer `Float` fields over boxed abstracts in arrays of primitives; prefer typed arrays (`haxe.io.Float32Array`, `ceramic.Float32Array`) for large numeric buffers.

## Tests

- Port the Rust `#[cfg(test)]` tests that check behaviour (not the ones that only check Rust traits or formatting).
- GPUI tests go in `test/unit/src/tests/<Module>Test.hx` and are registered in `test/unit/src/Tests.hx`. Run with `cd test/unit && ceramic headless run node --setup --assets`.
- Pure Haxe libraries in `ceramic/git/<lib>` carry their own `test/` folder, runnable without Ceramic (`haxe` with `--interp`, or Node).

## Credits and licenses

No license washing: ported code keeps its authors and license.

- Every port carries the header above. gpui-kit files use `Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.`
- [NOTICE.md](NOTICE.md) lists every upstream project, version, copyright holder and license; add an entry before porting anything new (libraries, shaders, icons, fonts, test fixtures).
- Upstream license texts live in `LICENSES/`.
- Standalone libraries in `ceramic/git/<lib>` ship the upstream `LICENSE` (with the original copyright) and a README naming the original project and the ported version.
- Assets follow the same rule: Lucide icons (ISC), fonts (OFL) and test fixtures get their license file and a NOTICE entry.

## Decisions taken while porting geometry and color

- Rust enums carrying data (`AbsoluteLength`, `DefiniteLength`, `Length`) are plain Haxe enums with the same names; their methods live in a `XxxTools` class attached with `@:using` (abstract wrappers would break nested pattern matching like `Definite(Absolute(Pixels(v)))`).
- `AbsoluteLength.Pixels` and `Rems` share their names with the unit types: import with `import gpui.*` and qualify enum constructors.
- Fieldless Rust enums (`Axis`, `Anchor`, `ColorSpace`, `BackgroundTag`, `BorderStyle`...) are `enum abstract(Int)`, with methods when needed.
- Methods Rust defines on one generic instantiation go in a module named after it (`EdgesOfLength.auto()`), attached with `@:using` when they are instance methods.
- Bridges between numeric and generic geometry: `mapOf<U>()` on numeric classes, `mapToPoint` / `mapToSize` / `mapToEdges` / `mapToCorners` / `mapToBounds` on generic ones.
- `From` conversions become `toX()` methods; `impl Into<X>` arguments become `abstract IntoX(X) from X` with `@:from` (`IntoHsla`, `IntoBackground`).
- Rust operators become `add`, `sub`, `mul`, `div`, `neg` methods; unit abstracts also get `@:op` overloads (comparisons included).
- `TryFrom<&str>` becomes `parse()` (throws) and `tryParse()` (returns null).
- Rust float semantics (`round` half away from zero, `rem_euclid`, `signum`, saturating casts) are in `gpui.util.MathUtil`: never use Haxe's `Math.round` on ported code.
- Builders whose name clashes with a field get a `with` prefix (`Background.withColorSpace`).
- Device pixels are stored as Float, so halving them is exact (Rust truncates).

## Deliberate deviations

The port must match the original GPUI and gpui-kit exactly. The only allowed differences are the fixes listed in [DEVIATIONS.md](DEVIATIONS.md), each motivated by a defect proven to exist in the original. A fix is applied to the port and, as a patch, to the copy of the original built by the reference harness, so the comparison stays strict. Any other difference is a bug of the port.

## Writing style

No em dash or en dash anywhere (code, comments, docs, commit messages). Rewrite the sentence with a comma, a colon, parentheses or two sentences.
