// Ported from gpui-kit 0.8.1: crates/story/locales/ui.yml
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from YAML to Haxe for Ceramic. See NOTICE.md.
package story;

/**
 * The story's own translations, layered over the component ones (Rust
 * `rust_i18n::i18n!("locales")` and `extend!(gpui_component)`).
 */
class StoryLocales {

    public static function json():String {
        return haxe.Json.stringify({
            fr: {
                'Calendar.week.0': 'Di',
                'Calendar.week.1': 'Lu',
                'Calendar.week.2': 'Ma',
                'Calendar.week.3': 'Me',
                'Calendar.week.4': 'Je',
                'Calendar.week.5': 'Ve',
                'Calendar.week.6': 'Sa',
                'Calendar.month.January': 'Janvier',
                'Calendar.month.February': 'Février',
                'Calendar.month.March': 'Mars',
                'Calendar.month.April': 'Avril',
                'Calendar.month.May': 'Mai',
                'Calendar.month.June': 'Juin',
                'Calendar.month.July': 'Juillet',
                'Calendar.month.August': 'Août',
                'Calendar.month.September': 'Septembre',
                'Calendar.month.October': 'Octobre',
                'Calendar.month.November': 'Novembre',
                'Calendar.month.December': 'Décembre',
                'DatePicker.placeholder': 'Sélectionner une date',
            }
        });
    }

}
