package be.appmire.secureqr.ui.content

import androidx.annotation.StringRes
import be.appmire.secureqr.R
import be.appmire.secureqr.qr.FieldLabel
import be.appmire.secureqr.qr.Notice
import be.appmire.secureqr.qr.QrAction
import be.appmire.secureqr.qr.QrType

/** Display copy for the parser's symbolic values. The parsers themselves hold no UI text. */

@StringRes
fun QrType.titleRes(): Int = when (this) {
    QrType.PAYLINK -> R.string.type_paylink
    QrType.URL -> R.string.type_url
    QrType.EPC -> R.string.type_epc
    QrType.EMV -> R.string.type_emv
    QrType.UPI -> R.string.type_upi
    QrType.CRYPTO -> R.string.type_crypto
    QrType.WIFI -> R.string.type_wifi
    QrType.CONTACT -> R.string.type_contact
    QrType.EVENT -> R.string.type_event
    QrType.EMAIL -> R.string.type_email
    QrType.PHONE -> R.string.type_phone
    QrType.SMS -> R.string.type_sms
    QrType.GEO -> R.string.type_geo
    QrType.OTP -> R.string.type_otp
    QrType.APPLINK -> R.string.type_applink
    QrType.TEXT -> R.string.type_text
}

@StringRes
fun FieldLabel.labelRes(): Int = when (this) {
    FieldLabel.BENEFICIARY -> R.string.field_beneficiary
    FieldLabel.IBAN -> R.string.field_iban
    FieldLabel.BIC -> R.string.field_bic
    FieldLabel.AMOUNT -> R.string.field_amount
    FieldLabel.REFERENCE -> R.string.field_reference
    FieldLabel.MESSAGE -> R.string.field_message
    FieldLabel.MERCHANT -> R.string.field_merchant
    FieldLabel.CITY -> R.string.field_city
    FieldLabel.COUNTRY -> R.string.field_country
    FieldLabel.CURRENCY -> R.string.field_currency
    FieldLabel.PAYEE_NAME -> R.string.field_payee_name
    FieldLabel.PAYEE_ADDRESS -> R.string.field_payee_address
    FieldLabel.NOTE -> R.string.field_note
    FieldLabel.NETWORK -> R.string.field_network
    FieldLabel.ADDRESS -> R.string.field_address
    FieldLabel.LABEL -> R.string.field_label
    FieldLabel.SECURITY -> R.string.field_security
    FieldLabel.PASSWORD -> R.string.field_password
    FieldLabel.HIDDEN -> R.string.field_hidden
    FieldLabel.NAME -> R.string.field_name
    FieldLabel.PHONE -> R.string.field_phone
    FieldLabel.EMAIL -> R.string.field_email
    FieldLabel.ORGANISATION -> R.string.field_organisation
    FieldLabel.URL -> R.string.field_url
    FieldLabel.TITLE -> R.string.field_title
    FieldLabel.START -> R.string.field_start
    FieldLabel.END -> R.string.field_end
    FieldLabel.LOCATION -> R.string.field_location
    FieldLabel.DESCRIPTION -> R.string.field_description
    FieldLabel.TO -> R.string.field_to
    FieldLabel.SUBJECT -> R.string.field_subject
    FieldLabel.BODY -> R.string.field_body
    FieldLabel.NUMBER -> R.string.field_number
    FieldLabel.LATITUDE -> R.string.field_latitude
    FieldLabel.LONGITUDE -> R.string.field_longitude
    FieldLabel.ISSUER -> R.string.field_issuer
    FieldLabel.ACCOUNT -> R.string.field_account
    FieldLabel.TYPE -> R.string.field_type
    FieldLabel.SCHEME -> R.string.field_scheme
    FieldLabel.TEXT -> R.string.field_text
    FieldLabel.PROVIDER -> R.string.field_provider
}

@StringRes
fun Notice.textRes(): Int = when (this) {
    Notice.INVALID_IBAN -> R.string.notice_invalid_iban
    Notice.OTP_SECRET -> R.string.notice_otp
    Notice.PAYMENT -> R.string.notice_payment
    Notice.PAYLINK -> R.string.notice_paylink
    Notice.EPC_INSTRUCTION -> R.string.notice_epc_instruction
    Notice.CRYPTO_IRREVERSIBLE -> R.string.notice_crypto
    Notice.WIFI_OPEN -> R.string.notice_wifi_open
    Notice.SMS_SHORT_CODE -> R.string.notice_sms_short_code
    Notice.APP_LINK -> R.string.notice_app_link
    Notice.LOCAL_ONLY -> R.string.notice_local_only
}

@StringRes
fun QrAction.labelRes(): Int = when (this) {
    QrAction.OPEN_IN_APP -> R.string.action_open_in_app
    QrAction.OPEN_IN_PAYMENT_APP -> R.string.action_open_in_payment_app
    QrAction.COPY -> R.string.action_copy
    QrAction.COPY_ALL -> R.string.action_copy_all
    QrAction.COPY_IBAN -> R.string.action_copy_iban
    QrAction.COPY_ADDRESS -> R.string.action_copy_address
    QrAction.COPY_PASSWORD -> R.string.action_copy_password
}
