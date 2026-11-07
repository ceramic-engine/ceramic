// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/diagnostic_styles.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.highlighter;

import gpui.App;
import gpui.Hsla;
import gpui.base.input.DiagnosticSeverity;
import gpui.component.theme.Theme;

/**
 * The colors of a diagnostic, from the status colors of the highlight theme.
 * (With the `StatusColors` of gpui-kit's builds without tree-sitter, they are
 * all transparent: see `StatusColors`.)
 */
class DiagnosticStyles {

    public static function diagnosticBackground(severity:DiagnosticSeverity, cx:App):Hsla {
        final status = Theme.global(cx).highlightTheme.style.status;
        return switch severity {
            case Error: status.errorBackground(cx);
            case Warning: status.warningBackground(cx);
            case Info: status.infoBackground(cx);
            case Hint: status.hintBackground(cx);
        }
    }

    public static function diagnosticForeground(severity:DiagnosticSeverity, cx:App):Hsla {
        final status = Theme.global(cx).highlightTheme.style.status;
        return switch severity {
            case Error: status.error(cx);
            case Warning: status.warning(cx);
            case Info: status.info(cx);
            case Hint: status.hint(cx);
        }
    }

    public static function diagnosticBorder(severity:DiagnosticSeverity, cx:App):Hsla {
        final status = Theme.global(cx).highlightTheme.style.status;
        return switch severity {
            case Error: status.errorBorder(cx);
            case Warning: status.warningBorder(cx);
            case Info: status.infoBorder(cx);
            case Hint: status.hintBorder(cx);
        }
    }

}
