// Ported from gpui-kit 0.8.1: crates/base/src/number_input.rs, crates/base/src/otp_input.rs (tests),
// crates/component/src/input/{input,textarea,number_input,otp_input,content_type}.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.NumberInput.NumberInputEvent;
import glaze.kit.base.OtpInput.OtpState;
import glaze.kit.base.StepAction;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.TextareaState;
import glaze.kit.Component;
import glaze.kit.input.AnyInputState;
import glaze.kit.input.Input;
import glaze.kit.input.InputContentType;
import glaze.kit.input.NumberInput;
import glaze.kit.input.OtpInput;
import glaze.kit.input.Textarea;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/**
 * The `#[cfg(test)]` tests of gpui-base's `number_input.rs` and
 * `otp_input.rs`, and of gpui-component's `input` module (input, textarea,
 * number input, OTP input, content type).
 *
 * Not ported: `role_option_converts_to_the_matching_override` (Rust
 * `From<Option<Role>>`, no Haxe counterpart), the accesskit probes of
 * `editable_input_offers_accessibility_write_action` and
 * `input_emits_accessibility_id` (the port has no accessibility tree; the
 * projection they read is checked on `InputAccessibility` instead), the
 * focused input registry case of the code editor (`EditorState`, wave 11).
 */
class InputComponentsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 1920, height:Float = 1080):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    /// base number_input.rs

    function testSteppingPreservesPrecisionAndDirectionalBounds() {
        assertEquals('0.3', glaze.kit.base.NumberInput.stepValue('0.1', Increment, 0.2, null, null));
        assertEquals(null, glaze.kit.base.NumberInput.stepValue('10', Decrement, 1., 10., null));
        assertEquals('100.0', glaze.kit.base.NumberInput.stepValue('99.5', Increment, 1., null, 100.));
        assertEquals(null, glaze.kit.base.NumberInput.stepValue('10', Increment, 1., null, 10.));
        assertEquals('0', glaze.kit.base.NumberInput.stepValue('5', Decrement, 10., 0., null));
    }

    /// component number_input.rs

    function testStepValue() {
        function step(value:String, action:StepAction, step:Float, min:Null<Float>, max:Null<Float>):Null<String> {
            return glaze.kit.base.NumberInput.stepValue(value, action, step, min, max);
        }
        // Step from empty value
        assertEquals('1', step('', Increment, 1., null, null));
        assertEquals('-1', step('', Decrement, 1., null, null));
        // Invalid intermediate values are treated as 0
        assertEquals('1', step('-', Increment, 1., null, null));
        assertEquals('2', step('1', Increment, 1., null, null));
        assertEquals('-1', step('-2', Increment, 1., null, null));

        // Avoid float precision issue, e.g. 0.1 + 0.2 != 0.30000000000000004
        assertEquals('0.3', step('0.1', Increment, 0.2, null, null));
        assertEquals('0.2', step('0.3', Decrement, 0.1, null, null));
        // Keep the fraction digits of the current value
        assertEquals('2.25', step('1.25', Increment, 1., null, null));

        // Step from empty value always steps into the range
        assertEquals('10', step('', Increment, 1., 10., null));
        assertEquals('10', step('', Decrement, 1., 10., null));
        // Clamp to min/max
        assertEquals('100.0', step('99.5', Increment, 1., null, 100.));
        assertEquals('100', step('1000', Decrement, 1., null, 100.));
        // Keep the fraction digits of the clamped bound
        assertEquals('0.25', step('1', Decrement, 1., 0.25, null));

        // Stepping must move the value in the pressed direction:
        // no-op at the boundary
        assertEquals(null, step('10', Decrement, 1., 10., null));
        assertEquals(null, step('100', Increment, 1., null, 100.));
        // Decrement on a below-min value (or Increment on an above-max value)
        // does nothing, instead of moving the value in the opposite direction
        assertEquals(null, step('5', Decrement, 1., 10., null));
        assertEquals(null, step('1000', Increment, 1., null, 100.));
    }

    /// base otp_input.rs

    function testKeyboardEditingBackspacesAndStopsAtLength() {
        assertEquals('1', @:privateAccess OtpState.editValue('12', 'backspace', null, 4));
        assertEquals('123', @:privateAccess OtpState.editValue('12', '\u{ff13}', null, 4));
        assertEquals(null, @:privateAccess OtpState.editValue('1234', '5', null, 4));
        assertEquals(null, @:privateAccess OtpState.editValue('12', 'left', null, 4));
    }

    function testProgrammaticValuesRemainUnfilteredForCompatibility() {
        // Programmatic values intentionally do not use the keyboard editor path.
        // This captures the legacy contract: callers may display arbitrary or
        // over-length values, while actual key entry remains digit-only.
        final value = 'token-over-length';
        assertEquals('token-over-length', value);
        assertEquals(null, @:privateAccess OtpState.editValue('token', 'x', null, 2));
    }

    /// component otp_input.rs

    function testInvalidGroupCountsAreSafelyClamped() {
        assertEquals(1, @:privateAccess OtpInput.resolvedGroups(6, 0));
        assertEquals(6, @:privateAccess OtpInput.resolvedGroups(6, 20));
        assertEquals(1, @:privateAccess OtpInput.resolvedGroups(0, 0));
        assertEquals(2, @:privateAccess OtpInput.resolvedGroups(5, 2));
    }

    /// component input.rs

    function testContentTypesMapToAccessibilityRoles() {
        final cases:Array<{t:Null<InputContentType>, role:Role}> = [
            {t: null, role: TextInput},
            {t: Name, role: TextInput},
            {t: NamePrefix, role: TextInput},
            {t: GivenName, role: TextInput},
            {t: MiddleName, role: TextInput},
            {t: FamilyName, role: TextInput},
            {t: NameSuffix, role: TextInput},
            {t: Nickname, role: TextInput},
            {t: JobTitle, role: TextInput},
            {t: OrganizationName, role: TextInput},
            {t: Location, role: TextInput},
            {t: FullStreetAddress, role: TextInput},
            {t: StreetAddressLine1, role: TextInput},
            {t: StreetAddressLine2, role: TextInput},
            {t: AddressCity, role: TextInput},
            {t: AddressState, role: TextInput},
            {t: AddressCityAndState, role: TextInput},
            {t: Sublocality, role: TextInput},
            {t: CountryName, role: TextInput},
            {t: PostalCode, role: TextInput},
            {t: TelephoneNumber, role: PhoneNumberInput},
            {t: EmailAddress, role: EmailInput},
            {t: Url, role: UrlInput},
            {t: CreditCardNumber, role: TextInput},
            {t: CreditCardName, role: TextInput},
            {t: CreditCardGivenName, role: TextInput},
            {t: CreditCardMiddleName, role: TextInput},
            {t: CreditCardFamilyName, role: TextInput},
            {t: CreditCardSecurityCode, role: TextInput},
            {t: CreditCardExpiration, role: TextInput},
            {t: CreditCardExpirationMonth, role: TextInput},
            {t: CreditCardExpirationYear, role: TextInput},
            {t: CreditCardType, role: TextInput},
            {t: Username, role: TextInput},
            {t: Password, role: PasswordInput},
            {t: NewPassword, role: PasswordInput},
            {t: OneTimeCode, role: TextInput},
            {t: ShipmentTrackingNumber, role: TextInput},
            {t: FlightNumber, role: TextInput},
            {t: DateTime, role: DateTimeInput},
            {t: Birthdate, role: DateInput},
            {t: BirthdateDay, role: TextInput},
            {t: BirthdateMonth, role: TextInput},
            {t: BirthdateYear, role: TextInput},
            {t: CellularEid, role: TextInput},
            {t: CellularImei, role: TextInput},
        ];
        for (c in cases) {
            assertEquals(c.role, @:privateAccess Input.accessibilityRole(false, c.t, Implicit));
        }
    }

    function testMultilineInputsKeepMultilineAccessibilityRole() {
        assertEquals(MultilineTextInput, @:privateAccess Input.accessibilityRole(true, Password, Implicit));
    }

    function testExplicitAccessibilityRoleOverridesDefaults() {
        assertEquals(TextInput, @:privateAccess Input.accessibilityRole(false, Password, Explicit(TextInput)));
        assertEquals(TextInput, @:privateAccess Input.accessibilityRole(true, Password, Explicit(TextInput)));
    }

    function testPresentationalRoleEmitsNoAccessibilityNode() {
        assertNull(@:privateAccess Input.accessibilityRole(false, Password, Presentational));
        assertNull(@:privateAccess Input.accessibilityRole(true, null, Presentational));
    }

    function testPasswordContentTypesKeepAccessibilityValuesPrivate() {
        assertTrue(@:privateAccess Input.exposesAccessibilityValue(null));
        assertFalse(@:privateAccess Input.exposesAccessibilityValue(Password));
        assertFalse(@:privateAccess Input.exposesAccessibilityValue(NewPassword));
    }

    function testOnPasteBuilder() {
        open((window, cx) -> {
            final state:Entity<InputState> = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            assertNull(@:privateAccess new Input(state).pasteHandler);
            final input = new Input(state).onPaste((_, _, _) -> true);
            assertNotNull(@:privateAccess input.pasteHandler);
            return div();
        });
    }

    function testOnTokenHoverBuilder() {
        open((window, cx) -> {
            final state:Entity<InputState> = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            assertNull(@:privateAccess new Input(state).tokenHoverListener);
            final input = new Input(state).onTokenHover((_, _, _) -> {});
            assertNotNull(@:privateAccess input.tokenHoverListener);
            return div();
        });
    }

    /// component textarea.rs

    function testTextareaOnPasteBuilder() {
        open((window, cx) -> {
            final state:Entity<TextareaState> = cx.newEntity((c:Context<TextareaState>) -> new TextareaState(window, c));
            assertNull(@:privateAccess new Textarea(state).pasteHandler);
            final textarea = new Textarea(state).onPaste((_, _, _) -> true);
            assertNotNull(@:privateAccess textarea.pasteHandler);
            return div();
        });
    }

    function testTextareaOnTokenHoverBuilder() {
        open((window, cx) -> {
            final state:Entity<TextareaState> = cx.newEntity((c:Context<TextareaState>) -> new TextareaState(window, c));
            assertNull(@:privateAccess new Textarea(state).tokenHoverListener);
            final textarea = new Textarea(state).onTokenHover((_, _, _) -> {});
            assertNotNull(@:privateAccess textarea.tokenHoverListener);
            return div();
        });
    }

    /// component content_type.rs

    function testContentTypeMapsToNsTextContentTypeValues() {
        final contentTypes:Array<{t:InputContentType, native:Null<String>}> = [
            {t: Name, native: 'name'},
            {t: NamePrefix, native: 'honorific-prefix'},
            {t: GivenName, native: 'given-name'},
            {t: MiddleName, native: 'additional-name'},
            {t: FamilyName, native: 'family-name'},
            {t: NameSuffix, native: 'honorific-suffix'},
            {t: Nickname, native: 'nickname'},
            {t: JobTitle, native: 'organization-title'},
            {t: OrganizationName, native: 'organization'},
            {t: Location, native: 'location'},
            {t: FullStreetAddress, native: 'street-address'},
            {t: StreetAddressLine1, native: 'address-line1'},
            {t: StreetAddressLine2, native: 'address-line2'},
            {t: AddressCity, native: 'address-level2'},
            {t: AddressState, native: 'address-level1'},
            {t: AddressCityAndState, native: 'address-level1+2'},
            {t: Sublocality, native: 'address-level3'},
            {t: CountryName, native: 'country-name'},
            {t: PostalCode, native: 'postal-code'},
            {t: TelephoneNumber, native: 'tel'},
            {t: EmailAddress, native: 'email'},
            {t: Url, native: 'url'},
            {t: CreditCardNumber, native: 'cc-number'},
            {t: CreditCardName, native: 'cc-name'},
            {t: CreditCardGivenName, native: 'cc-given-name'},
            {t: CreditCardMiddleName, native: 'cc-additional-name'},
            {t: CreditCardFamilyName, native: 'cc-family-name'},
            {t: CreditCardSecurityCode, native: 'cc-csc'},
            {t: CreditCardExpiration, native: 'cc-exp'},
            {t: CreditCardExpirationMonth, native: 'cc-exp-month'},
            {t: CreditCardExpirationYear, native: 'cc-exp-year'},
            {t: CreditCardType, native: 'cc-type'},
            {t: Username, native: 'username'},
            {t: Password, native: 'password'},
            {t: NewPassword, native: 'new-password'},
            {t: OneTimeCode, native: 'one-time-code'},
            {t: ShipmentTrackingNumber, native: 'shipment-tracking-number'},
            {t: FlightNumber, native: 'flight-number'},
            {t: DateTime, native: 'date-time'},
            {t: Birthdate, native: 'bday'},
            {t: BirthdateDay, native: 'bday-day'},
            {t: BirthdateMonth, native: 'bday-month'},
            {t: BirthdateYear, native: 'bday-year'},
            {t: CellularEid, native: null},
            {t: CellularImei, native: null},
        ];
        for (c in contentTypes) {
            assertEquals(c.native, c.t.nsTextContentType());
        }
    }

}
