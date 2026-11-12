# QR payload types

Both apps classify the scanned text on-device, in this order (first match
wins), and show a typed card. **Only `url` payloads go to the server.** Nothing
is opened, joined, dialled or paid without an explicit tap.

Matching is case-insensitive on the prefix; trim surrounding whitespace first.

| type | detect | fields shown | actions |
|---|---|---|---|
| `login` | a sign-in code of a chat or game service, see "Sign-in codes of other services" | Service | none |
| `chat` | a chat link, see "Chat links" | Service, Number or Handle, Message | Open in app, Copy |
| `paylink` | `http`/`https` URL whose host is in the payment-app table below | Provider, Amount, Description, Reference (when present) | Open in payment app, Copy |
| `url` | scheme `http`/`https` | (server preview flow) | preview flow |
| `epc` | first line `BCD` and 4th line `SCT` | Beneficiary, IBAN, BIC, Amount, Reference, Message | Copy IBAN, Copy all |
| `swissqr` | first line `SPC` (Swiss QR-bill) | Beneficiary, IBAN, Amount, Reference, Message | Copy IBAN, Copy all |
| `spd` | starts with `SPD*` (Czech payment code) | Beneficiary, IBAN, Amount, Reference, Message | Copy IBAN, Copy all |
| `emv` | starts with `000201` and TLV-parses cleanly | Provider (Pix only), Merchant, City, Country, Amount, Currency, Payee address (Pix key) | Copy all |
| `upi` | `upi://pay` | Payee name (`pn`), Payee address (`pa`), Amount (`am`), Currency (`cu`), Note (`tn`) | Open in app, Copy |
| `crypto` | `bitcoin:`, `ethereum:`, `litecoin:`, `bitcoincash:`, `lightning:` | Network, Address, Amount (`amount`/`value`), Label, Message | Open in app, Copy address |
| `wifi` | `WIFI:` | Network (S), Security (T), Password (P, masked with reveal), Hidden (H) | Join network, Copy password |
| `contact` | `BEGIN:VCARD` or `MECARD:` | Name, Phone(s), Email(s), Organisation, Address, URL | Add to contacts, Copy all |
| `event` | `BEGIN:VEVENT` or `BEGIN:VCALENDAR` | Title, Start, End, Location, Description | Add to calendar (when Start parses), Copy all |
| `email` | `mailto:` or `MATMSG:` | To, Subject, Body | Open in app, Copy |
| `phone` | `tel:` | Number | Open in app, Copy (Copy only for a service code) |
| `sms` | `sms:`, `smsto:` | Number, Message | Open in app, Copy |
| `geo` | `geo:` | Latitude, Longitude, Label (`q`) | Open in app, Copy |
| `otp` | `otpauth://` | Issuer, Account, Type (secret is never displayed) | Copy |
| `otpexport` | `otpauth-migration://` | none | none |
| `esim` | `LPA:` | Address (the provider's server), Activation code (masked with reveal) | Copy |
| `device` | `MT:` (Matter), `X-HM://` (HomeKit), `DPP:` (Wi-Fi Easy Connect) | Type (`Matter`, `HomeKit`, `Wi-Fi Easy Connect`) | none |
| `healthcert` | `HC1:` (EU certificate), `shc:/` (SMART Health Card) | none | none |
| `unsafe` | scheme in the unsafe list, see "Links that must not be opened" | Scheme, full text | Copy |
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

**Wi-Fi (`wifi`).** "Join network" asks the system to add the network, and the
system asks the user before anything is saved: "Save this network?" on Android
11 and up, "Wants to Join Wi-Fi Network" on iOS (Hotspot Configuration
entitlement). On older Android, and for kinds the system dialog cannot take
(WEP, company sign-in), the password is copied and the Wi-Fi settings open.
For a network without a password the copy action stays the accent button and
"Join network" the quiet one. No action when the code has no network name.

**SEPA bank transfers (`epc`).** These are plain text, not a link, so there is
nothing to open. The card tells the user what to do instead (see notices) and
offers Copy IBAN and Copy all. No share or open action.

## Sign-in codes of other services (`login`)

Scanning one of these with the service's own app signs **another device** in
to the user's account. Sent by a stranger, it is an account takeover. They are
never sent to the server (visiting the link could use up or advance the
session), never opened, never copied, and never kept in history in full.

| detect | service shown |
|---|---|
| `http(s)` host `discord.com` or `discordapp.com`, path starts `/ra/` | Discord |
| `http(s)` host `s.team`, path starts `/q/` | Steam |
| `http(s)` host `login.weixin.qq.com`, path starts `/l/` | WeChat |
| `tg://login` | Telegram |
| `sgnl://linkdevice` or `tsdevice:` | Signal |
| whole text matches `^[12]@[A-Za-z0-9+/=_-]{16,}(,[A-Za-z0-9+/=_-]{16,}){2,}$` | WhatsApp |

Hosts match exactly or as a subdomain, as for payment apps; paths and schemes
case-insensitively.

## Chat links (`chat`)

Checked after `login`. Not sent to the server; "Open in app" replays the
original text.

| detect | service | number / handle |
|---|---|---|
| host `wa.me`, or `api.whatsapp.com` with path `/send`, or `whatsapp://send` | WhatsApp | Number: the first path segment of `wa.me`, else the `phone` parameter, shown with a leading `+` |
| host `t.me` or `telegram.me`, or `tg://resolve` | Telegram | Handle: the first path segment (`@name`), or the `domain` parameter; an invite (`+…` or `joinchat/…`) is shown as Handle "Invite link" |
| host `m.me` | Messenger | Handle: first path segment |
| host `signal.me` | Signal | none |
| `viber://chat` or `viber://add` | Viber | Number: the `number` parameter |

Message is the `text` parameter when present. A chat link with neither number
nor handle still gets the card.

## Links that must not be opened (`unsafe`)

Schemes: `javascript`, `data`, `vbscript`, `file`, `blob`, `content`,
`intent`, `android-app`, `chrome`, `about`, `view-source`, `jar`. Checked
before `applink`. The card shows the scheme and the text; the only action is
Copy.

## Phone service codes and premium numbers (`phone`)

The number is the text after `tel:`, percent-decoded.

- It contains `*` or `#` → **service code**: danger notice, and the only
  action is Copy (never "Open in app").
- Otherwise strip spaces, dashes, dots and brackets, and it is a **premium
  number** (caution notice, actions unchanged) when it matches one of:
  `^(\+|00)(32|31|49|43|41)90\d`, `^090\d`, `^(\+|00)449\d`,
  `^09[018]\d`, `^(\+?1)?900\d{7}$`.

## Notices (shown on the card, styled like the verdict banner)

- `login` → danger: "This code signs another device in to your account. Only
  scan it from inside that app, on a screen you opened yourself. If someone
  sent it to you, it is a scam."
- `chat` → caution: "This starts a chat with someone you may not know.
  Scammers use chat links to move a conversation away from a site you trust."
- `otpexport` → danger: "This code holds the secrets of every account in an
  authenticator app. Whoever scans it can make your sign-in codes. Only scan
  it with your own new phone, and never share it."
- `esim` → instruction, shown first like the bank-transfer one: "To install
  it, open your phone's mobile network settings and add an eSIM." Then
  caution: "This installs a mobile plan (eSIM) on your phone. Only continue
  if it comes from your own mobile provider."
- `device` → caution: "This is a setup code for a smart-home device. Whoever
  scans it can add the device to their own home. Only scan it with your
  smart-home app, for a device you own."
- `healthcert` → caution: "This is a health certificate. It holds a name, a
  date of birth and medical details. It was read on your phone and not sent
  anywhere. Do not share it."
- `unsafe` → danger: "This is not a web address. Links of this kind can run
  code or open files on your phone. Do not open it."
- `phone` service code → danger: "This is a phone service code, not a normal
  number. Such codes can forward your calls, change settings or cost money.
  Only dial it if your provider told you to."
- `phone` premium number → caution: "This looks like a premium-rate number.
  Calling it can cost a lot per minute."
- `swissqr`, `spd` → exactly as `epc`: the instruction line, the payment
  caution, and the invalid-IBAN danger.
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

## Secrets in history and raw content

History and "Show raw content" never hold a secret. Besides the Wi-Fi
password and the `otpauth` secret:

| type | what is kept |
|---|---|
| `login` | the service only; raw becomes the text up to and including the first `/`-terminated host or the scheme, followed by `…` (WhatsApp: `…` only) |
| `otpexport` | `otpauth-migration://…` |
| `esim` | `LPA:1$<address>$…` (activation code dropped) |
| `device` | the prefix (`MT:`, `X-HM://`, `DPP:`) followed by `…` |
| `healthcert` | the prefix (`HC1:`, `shc:/`) followed by `…` |

## Adding to contacts and calendar

"Add to contacts" and "Add to calendar" open the system's own new-contact or
new-event screen, filled in from the code, where the user saves or cancels.
The apps ask for no contacts or calendar permission. "Add to calendar" is
only offered when the start date parses (`YYYYMMDD` or `YYYYMMDDTHHMM[SS][Z]`);
a date without a time is an all-day event; a time without `Z` is local time.

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

**Swiss QR-bill.** Lines as for EPC. Line 0 `SPC`, 1 version, 2 coding, 3 IBAN,
5 creditor name, 18 amount, 19 currency, 28 reference, 29 message. Amount is
shown as `<amount> <currency>`. Same IBAN check as EPC.

**SPD (Czech).** `SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*MSG:Text*RN:Name*X-VS:1234`.
`*`-separated `KEY:value`, values percent-decoded. `ACC` is the IBAN
(optionally `IBAN+BIC`; take the part before `+`), `AM` + `CC` the amount,
`RN` the beneficiary, `MSG` the message, `X-VS` the reference.

**Pix (Brazil).** An `emv` code whose merchant account template (any tag 26
to 51) parses as TLV with sub-tag `00` equal to `br.gov.bcb.pix`
(case-insensitive): Provider `Pix`, and Payee address from sub-tag `01` (the
key) or, when absent, sub-tag `25` (the payment link).

**eSIM.** `LPA:1$<address>$<activation code>[$…]`: split on `$`; part 1 is the
address, part 2 the activation code.

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
| `https://discord.com/ra/AbCdEf123456` | login | service Discord, no actions |
| `https://s.team/q/1/1234567890` | login | service Steam |
| `tg://login?token=abc` | login | service Telegram |
| `2@AbCdEfGhIjKlMnOpQrSt,UvWxYzAbCdEfGhIjKl,MnOpQrStUvWxYzAb,CdEfGhIjKlMnOpQr` | login | service WhatsApp |
| `https://discord.com/invite/abc` | url | not a sign-in path |
| `https://wa.me/3212345678?text=Hi%20there` | chat | service WhatsApp, number `+3212345678`, message "Hi there" |
| `https://t.me/some_shop` | chat | service Telegram, handle `@some_shop` |
| `tg://resolve?domain=some_shop` | chat | handle `@some_shop` |
| `https://example.com/a` | url | |
| `HTTP://EXAMPLE.COM` | url | |
| `BCD\n002\n1\nSCT\nGKCCBEBB\nRode Kruis\nBE72000000001616\nEUR25.00\n\n\nGift\n` | epc | name "Rode Kruis", amount 25.00 EUR, IBAN valid |
| `BCD\n002\n1\nSCT\n\nX\nBE72000000001617\nEUR1\n` | epc | IBAN invalid → danger notice |
| `00020101021129370016A000000677010111011300660000000005802TH530376454031005913Test Merchant6007Bangkok6304ABCD` | emv | merchant "Test Merchant", city "Bangkok", amount 100, currency THB |
| `SPC\n0200\n1\nCH4431999123000889012\nS\nRobert Schneider AG\nRue du Lac\n1268\n2501\nBiel\nCH\n\n\n\n\n\n\n\n1949.75\nCHF\n\n\n\n\n\n\n\nQRR\n210000000003139471430009017\nOrder 42\nEPD` | swissqr | name "Robert Schneider AG", amount `1949.75 CHF`, IBAN valid, reference set, message "Order 42" |
| `SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK*MSG:Platba%20za%20zbozi*RN:Jan Novak*X-VS:1234567890` | spd | name "Jan Novak", amount `480.50 CZK`, IBAN valid, message "Platba za zbozi", reference `1234567890` |
| `00020126360014br.gov.bcb.pix0114+5561999999999520400005303986540510.005802BR5908Loja Sul6008Brasilia6304ABCD` | emv | provider Pix, payee address `+5561999999999`, merchant "Loja Sul", amount 10.00, currency BRL |
| `upi://pay?pa=shop@bank&pn=Corner%20Shop&am=120.50&cu=INR` | upi | name "Corner Shop", amount 120.50 |
| `bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01` | crypto | amount 0.01 |
| `WIFI:T:WPA;S:Cafe\;Bar;P:p\:ss;;` | wifi | ssid `Cafe;Bar`, password `p:ss` |
| `WIFI:T:nopass;S:Open;;` | wifi | caution notice |
| `MECARD:N:Doe,John;TEL:+3212345678;;` | contact | actions Add to contacts, Copy all |
| `BEGIN:VEVENT\nSUMMARY:Team lunch\nDTSTART:20261203T120000Z\nDTEND:20261203T130000Z\nLOCATION:Canteen\nEND:VEVENT` | event | actions Add to calendar, Copy all |
| `BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT` | event | actions Copy all only |
| `tel:+3212345678` | phone | neutral, Open in app + Copy |
| `tel:*21*0032475000000%23` | phone | number `*21*0032475000000#`, danger, Copy only |
| `tel:090312345` | phone | premium caution |
| `tel:+32 903 12 345` | phone | premium caution |
| `smsto:3333:WIN` | sms | short-code caution |
| `geo:50.85,4.35?q=Brussels` | geo | |
| `otpauth://totp/Acme:joe?secret=JBSWY3DPEHPK3PXP&issuer=Acme` | otp | secret not displayed |
| `otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU` | otpexport | danger, no actions, raw shown as `otpauth-migration://…` |
| `LPA:1$smdp.example.com$ABCD-1234-EFGH` | esim | address `smdp.example.com`, activation code masked, raw shown as `LPA:1$smdp.example.com$…` |
| `MT:Y.K9042C00KA0648G00` | device | type Matter, no actions |
| `X-HM://0023ISYWYABCD` | device | type HomeKit |
| `HC1:6BF+70790T9WJWG.FKY*4GO0.O1CV2 O5 N2FBBRW1*70HS8WY04AC*WIFN0AHCD8KD97TK0F90KECTHGWJC0FDC:5AIA%G7X+AQB9746HS80:54IBQF60R6$A80X6S1BTYACG6M+9XG8KIAWNA91AY%67092L4WJCT3EHS8XJC$+DXJCCWENF6OF63W5NW6WF6%JC QE/IAYJC5LEW34U3ET7DXC9 QE-ED8%E.JCBECB1A-:8$96646AL60A60S6Q$D.UDRYA 96NF6L/5QW6307KQEPD09WEQDD+Q6TW6FA7C466KCN9E%961A6DL6FA7D46JPCT3E5JDLA7$Q6E464W5TG6..DX%DZJC6/DTZ9 QE5$CB$DA/D JC1/D3Z8WED1ECW.CCWE.Y92OAGY8MY9L+9MPCG/D5 C5IA5N9$PC5$CUZCY$5Y$527B+A4KZNQG5TKOWWD9FL%I8U$F7O2IBM85CWOC%LEZU4R/BXHDAHN 11$CA5MRI:AONFN7091K9FKIGIY%VWSSSU9%01FO2*FTPQ3C3F` | healthcert | caution, no actions, raw shown as `HC1:…` |
| `javascript:alert(1)` | unsafe | scheme `javascript`, danger, Copy only |
| `intent://scan/#Intent;scheme=zxing;end` | unsafe | scheme `intent` |
| `spotify:track:123` | applink | |
| `hello world` | text | |
| `000201 not tlv` | text | |
