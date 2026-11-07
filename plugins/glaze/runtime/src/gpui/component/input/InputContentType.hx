// Ported from gpui-kit 0.8.1: crates/component/src/input/content_type.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.Window;

/**
 * Semantic content type for an `Input`.
 *
 * These variants mirror Swift's text content types.
 */
enum abstract InputContentType(Int) {
    /** A person's full name. */
    var Name = 0;
    /** A name prefix, such as Mr. or Dr. */
    var NamePrefix = 1;
    /** A person's given name. */
    var GivenName = 2;
    /** A person's middle name. */
    var MiddleName = 3;
    /** A person's family name. */
    var FamilyName = 4;
    /** A name suffix, such as Jr. or PhD. */
    var NameSuffix = 5;
    /** A nickname. */
    var Nickname = 6;
    /** A job title. */
    var JobTitle = 7;
    /** An organization or company name. */
    var OrganizationName = 8;
    /** A location name. */
    var Location = 9;
    /** A full street address. */
    var FullStreetAddress = 10;
    /** The first line of a street address. */
    var StreetAddressLine1 = 11;
    /** The second line of a street address. */
    var StreetAddressLine2 = 12;
    /** A city or locality. */
    var AddressCity = 13;
    /** A state, province, or region. */
    var AddressState = 14;
    /** A combined city and state. */
    var AddressCityAndState = 15;
    /** A sublocality, district, or neighborhood. */
    var Sublocality = 16;
    /** A country name. */
    var CountryName = 17;
    /** A postal or ZIP code. */
    var PostalCode = 18;
    /** A telephone number. */
    var TelephoneNumber = 19;
    /** An email address. */
    var EmailAddress = 20;
    /** A URL. */
    var Url = 21;
    /** A credit card number. */
    var CreditCardNumber = 22;
    /** The full name on a credit card. */
    var CreditCardName = 23;
    /** The given name on a credit card. */
    var CreditCardGivenName = 24;
    /** The middle name on a credit card. */
    var CreditCardMiddleName = 25;
    /** The family name on a credit card. */
    var CreditCardFamilyName = 26;
    /** The security code on a credit card. */
    var CreditCardSecurityCode = 27;
    /** A credit card expiration date. */
    var CreditCardExpiration = 28;
    /** A credit card expiration month. */
    var CreditCardExpirationMonth = 29;
    /** A credit card expiration year. */
    var CreditCardExpirationYear = 30;
    /** A credit card type. */
    var CreditCardType = 31;
    /** A username or account identifier. */
    var Username = 32;
    /** The password for the account identified by the username field. */
    var Password = 33;
    /** A new password, such as during sign up or password reset. */
    var NewPassword = 34;
    /** A one-time verification code. */
    var OneTimeCode = 35;
    /** A parcel shipment tracking number. */
    var ShipmentTrackingNumber = 36;
    /** An airline flight number. */
    var FlightNumber = 37;
    /** A date, time, or duration. */
    var DateTime = 38;
    /** A birthdate. */
    var Birthdate = 39;
    /** A birthdate day. */
    var BirthdateDay = 40;
    /** A birthdate month. */
    var BirthdateMonth = 41;
    /** A birthdate year. */
    var BirthdateYear = 42;
    /** An eSIM EID. */
    var CellularEid = 43;
    /** A cellular IMEI. */
    var CellularImei = 44;

    /**
     * The value of `NSTextContentType` the macOS text field gets for this
     * content type (Rust compiles it on macOS only).
     */
    public function nsTextContentType():Null<String> {
        return switch (cast this : InputContentType) {
            case Name: "name";
            case NamePrefix: "honorific-prefix";
            case GivenName: "given-name";
            case MiddleName: "additional-name";
            case FamilyName: "family-name";
            case NameSuffix: "honorific-suffix";
            case Nickname: "nickname";
            case JobTitle: "organization-title";
            case OrganizationName: "organization";
            case Location: "location";
            case FullStreetAddress: "street-address";
            case StreetAddressLine1: "address-line1";
            case StreetAddressLine2: "address-line2";
            case AddressCity: "address-level2";
            case AddressState: "address-level1";
            case AddressCityAndState: "address-level1+2";
            case Sublocality: "address-level3";
            case CountryName: "country-name";
            case PostalCode: "postal-code";
            case TelephoneNumber: "tel";
            case EmailAddress: "email";
            case Url: "url";
            case CreditCardNumber: "cc-number";
            case CreditCardName: "cc-name";
            case CreditCardGivenName: "cc-given-name";
            case CreditCardMiddleName: "cc-additional-name";
            case CreditCardFamilyName: "cc-family-name";
            case CreditCardSecurityCode: "cc-csc";
            case CreditCardExpiration: "cc-exp";
            case CreditCardExpirationMonth: "cc-exp-month";
            case CreditCardExpirationYear: "cc-exp-year";
            case CreditCardType: "cc-type";
            case Username: "username";
            case Password: "password";
            case NewPassword: "new-password";
            case OneTimeCode: "one-time-code";
            case ShipmentTrackingNumber: "shipment-tracking-number";
            case FlightNumber: "flight-number";
            case DateTime: "date-time";
            case Birthdate: "bday";
            case BirthdateDay: "bday-day";
            case BirthdateMonth: "bday-month";
            case BirthdateYear: "bday-year";
            case CellularEid | CellularImei: null;
        }
    }

    /**
     * Tells the OS what the focused input is used for, to let the autofill offer
     * the matched value.
     *
     * The `editable` is false when the input is `disabled` or `readonly`, in that
     * case the autofill has nothing to fill in, so the content type is not synced.
     *
     * Ceramic has no native text field to tell: like the Rust build for tests
     * and for other platforms than macOS, this does nothing.
     */
    @:allow(gpui.component.input)
    static function syncNativeContentType(window:Window, contentType:Null<InputContentType>, editable:Bool):Void {
        if (!editable) {
            return;
        }
    }

}
