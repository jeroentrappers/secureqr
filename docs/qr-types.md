# QR payload types

Both apps classify the scanned text on-device, in this order (first match
wins), and show a typed card. **Only `url` payloads go to the server.** Nothing
is opened, joined, dialled or paid without an explicit tap.

Matching is case-insensitive on the prefix; trim surrounding whitespace first.

| type | detect | fields shown | actions |
|---|---|---|---|
| `paylink` | `http`/`https` URL whose host is in the payment-app table below | Provider, Amount, Description, Reference (when present) | Open in payment app, Copy |
| `url` | scheme `http`/`https` | (server preview flow) | preview flow |
| `epc` | first line `BCD` and 4th line `SCT` | Beneficiary, IBAN, BIC, Amount, Reference, Message | Copy IBAN, Copy all |
| `emv` | starts with `000201` and TLV-parses cleanly | Merchant, City, Country, Amount, Currency | Copy all |
| `upi` | `upi://pay` | Payee name (`pn`), Payee address (`pa`), Amount (`am`), Currency (`cu`), Note (`tn`) | Open in app, Copy |
| `crypto` | `bitcoin:`, `ethereum:`, `litecoin:`, `bitcoincash:`, `lightning:` | Network, Address, Amount (`amount`/`value`), Label, Message | Open in app, Copy address |
| `wifi` | `WIFI:` | Network (S), Security (T), Password (P, masked with reveal), Hidden (H) | Copy password |
| `contact` | `BEGIN:VCARD` or `MECARD:` | Name, Phone(s), Email(s), Organisation, Address, URL | Copy all |
| `event` | `BEGIN:VEVENT` or `BEGIN:VCALENDAR` | Title, Start, End, Location, Description | Copy all |
| `email` | `mailto:` or `MATMSG:` | To, Subject, Body | Open in app, Copy |
| `phone` | `tel:` | Number | Open in app, Copy |
| `sms` | `sms:`, `smsto:` | Number, Message | Open in app, Copy |
| `geo` | `geo:` | Latitude, Longitude, Label (`q`) | Open in app, Copy |
| `otp` | `otpauth://` | Issuer, Account, Type (secret is never displayed) | Copy |
| `applink` | any other `scheme:` matching `^[a-z][a-z0-9+.-]{1,31}:` | Scheme, full text | Open in app, Copy |
| `text` | anything else | raw text | Copy |

Every card has a title line ("Bank transfer", "Wi-Fi network", …), the fields
as label/value rows (values in mono where they are identifiers), a notice line,
and the raw payload in a collapsed "Show raw content" section.

## Handing over to other apps

Whatever is handed to the OS is the **original scanned text, unchanged**
("replay"). The apps never build a new link from parsed fields.

**Payment-app links (`paylink`).** Web links that belong to a payment app are
not sent to the server (visiting one could touch a payment session). They get a
card titled with the provider, and "Open in payment app" opens the original
link with a plain system open, so the installed app claims it; without the app
the provider's own page opens in the browser. The table is deliberately short
and lives in one place per app:

| host (and its subdomains) | provider shown |
|---|---|
| `payconiq.com` | Bancontact (Payconiq) |

Payconiq links look like `https://payconiq.com/l/1/<profile>/<pos>` (fixed
sticker) or `https://payconiq.com/t/1/<profile>?D=<description>&A=<amount in
euro cents>&R=<reference>` (invoice); host and scheme may be upper case. Show
A as euros (`A=1250` → `12.50 EUR`), D and R percent-decoded; all optional.

Wero and other wallets have no single published link format yet, so their
links take the normal preview route; "Open" then replays the original link
and the wallet app takes over if it claims it. Add hosts to the table as they
are confirmed.

**SEPA bank transfers (`epc`).** These are plain text, not a link, so there is
nothing to open. The card tells the user what to do instead (see notices) and
offers Copy IBAN and Copy all. No share or open action.

## Notices (shown on the card, styled like the verdict banner)

- `epc`, `emv`, `upi`, `crypto`, `paylink` → caution: "This is a payment request. Check
  the name, account and amount before you pay. Payments are hard to undo."
  - `epc` adds a neutral instruction line, shown first and prominently: "To
    pay, open your banking app and scan this QR code with it."
  - `paylink` uses "Check the name and amount in your payment app before you
    confirm." as its second sentence instead of the account wording.
  - `crypto` adds: "Crypto payments cannot be reversed."
  - `epc` with an IBAN failing the mod-97 check → danger: "The account number
    is not a valid IBAN."
- `otp` → danger: "This is a sign-in secret. Only scan it into your own
  authenticator app, and never share it."
- `wifi` with security `nopass`/empty → caution: "This network has no password.
  Anyone nearby can see your traffic."
- `sms` → caution if the number is 3-6 digits (short code): "Messages to short
  numbers can cost money."
- `applink` → caution: "This opens another app. Only continue if you expected that."
- everything else → neutral: "This was read on your phone and not sent anywhere."

"Open in app" hands the original payload to the OS; if no app handles it, say so.

## Parsing details

**EPC (SEPA credit transfer, EPC069-12).** Lines separated by `\n` or `\r\n`:

```
0 BCD            service tag
1 001|002        version
2 1..8           charset
3 SCT            identification
4 BIC            (optional in v002)
5 Name           beneficiary
6 IBAN
7 EUR12.34       amount (optional)
8 purpose        (optional)
9 structured reference (optional)
10 unstructured message (optional)
11 information   (optional)
```

Missing trailing lines are empty. Display IBAN grouped in fours. IBAN check:
strip spaces, move the first four characters to the end, map A-Z to 10-35,
the number mod 97 must equal 1.

**EMV merchant QR (EMVCo MPM).** A sequence of `TT LL value` items: two-digit
tag, two-digit decimal length, then that many characters. Tags: `59` merchant
name, `60` city, `58` country code, `54` amount, `53` ISO 4217 numeric currency
(map at least 978 EUR, 840 USD, 826 GBP, 756 CHF, 356 INR, 702 SGD, 764 THB,
986 BRL; otherwise show the number), `63` CRC (last). If the string does not
consume cleanly as TLV, fall through to `text`.

**Wi-Fi.** `WIFI:T:WPA;S:name;P:secret;H:true;;` Fields are `;`-separated
`K:value`; `\;`, `\:`, `\,` and `\\` are escapes.

**MECARD.** `MECARD:N:Doe,John;TEL:123;EMAIL:a@b.c;;` same escaping as Wi-Fi.
**vCard.** Read `FN` (or `N`), `TEL`, `EMAIL`, `ORG`, `ADR`, `URL` lines; ignore parameters after `;` in the property name.
**Event.** Read `SUMMARY`, `DTSTART`, `DTEND`, `LOCATION`, `DESCRIPTION`.
**MATMSG.** `MATMSG:TO:a@b.c;SUB:Hi;BODY:Text;;`
**URI types** (`upi`, `crypto`, `mailto`, `sms`, `geo`, `otpauth`): split on the first `?`, percent-decode query values.

## Shared test vectors

Both apps must unit-test the classifier with at least these:

| payload | type | check |
|---|---|---|
| `https://payconiq.com/t/1/5f2a9c0e1b?D=Invoice%2042&A=1250&R=INV42` | paylink | provider Bancontact (Payconiq), amount 12.50 EUR, description "Invoice 42", reference "INV42" |
| `HTTPS://PAYCONIQ.COM/L/1/5F2A9C0E1B/POS01` | paylink | no amount |
| `https://payconiq.com.evil.example/t/1/x` | url | not a payment-app host |
| `https://example.com/a` | url | |
| `HTTP://EXAMPLE.COM` | url | |
| `BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift\n` | epc | name "Rode Kruis", amount 25.00 EUR, IBAN valid |
| `BCD\n002\n1\nSCT\n\nX\nBE72000000001617\nEUR1\n` | epc | IBAN invalid → danger notice |
| `00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD` | emv | merchant "Test Merchant", city "Bangkok", amount 100, currency THB |
| `upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR` | upi | name "Corner Shop", amount 120.50 |
| `bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01` | crypto | amount 0.01 |
| `WIFI:T:WPA;S:Cafe\;Bar;P:p\:ss;;` | wifi | ssid `Cafe;Bar`, password `p:ss` |
| `WIFI:T:nopass;S:Open;;` | wifi | caution notice |
| `MECARD:N:Doe,John;TEL:+3212345678;;` | contact | |
| `tel:+3212345678` | phone | |
| `smsto:3333:WIN` | sms | short-code caution |
| `geo:50.85,4.35?q=Brussels` | geo | |
| `otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme` | otp | secret not displayed |
| `spotify:track:123` | applink | |
| `hello world` | text | |
| `000201 not tlv` | text | |
