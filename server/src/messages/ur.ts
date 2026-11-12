// Urdu
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} نے اسے خطرناک قرار دیا ہے',
  'reason.download': 'لنک نے ایک فائل ڈاؤن لوڈ کرنے کی کوشش کی',
  'reason.not_https': 'آخری صفحہ انکرپٹڈ نہیں ہے',
  'reason.ip_address': 'پتہ صرف ایک نمبر ہے، نام نہیں',
  'reason.lookalike_domain': 'پتے میں ملتے جلتے حروف استعمال ہوئے ہیں',
  'reason.embedded_credentials': 'لنک پتے کے اندر ایک لاگ اِن نام چھپاتا ہے',
  'reason.domain_changed': 'شروع ایک سائٹ سے، اختتام دوسری پر',
  'reason.opens_app': 'لنک ایک دوسری ایپ کھولنے کی کوشش کرتا ہے ({scheme})',
  'reason.asks_for_payment': 'صفحہ کارڈ کی تفصیلات مانگتا ہے',
  'reason.asks_for_password': 'صفحہ پاس ورڈ مانگتا ہے',
  'reason.many_redirects': { one: '{count} ری ڈائریکٹ سے گزرا', other: '{count} ری ڈائریکٹ سے گزرا' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'بلاک لسٹس کی جانچ',
  'step.listed': '{providers} نے اسے خطرناک قرار دیا ہے',
  'step.not_listed': { one: 'بلاک لسٹ میں نہیں', other: '{count} بلاک لسٹس میں نہیں' },
  'step.lists_unreachable': 'بلاک لسٹس تک رسائی نہیں ہو سکی',
  'step.address': 'پتہ تلاش ہو رہا ہے',
  'step.address_done': 'پتہ مل گیا',
  'step.follow': 'لنک کھولا جا رہا ہے',
  'step.redirects': { zero: 'کوئی ری ڈائریکٹ نہیں', one: '{count} ری ڈائریکٹ', other: '{count} ری ڈائریکٹ' },
  'step.page': 'صفحہ لوڈ ہو رہا ہے',
  'step.page_done': 'صفحہ لوڈ ہو گیا',
  'step.forms': 'سائن اِن اور ادائیگی کے فارم کی تلاش',
  'step.forms_both': 'پاس ورڈ اور کارڈ کی تفصیلات مانگتا ہے',
  'step.forms_password': 'پاس ورڈ مانگتا ہے',
  'step.forms_card': 'کارڈ کی تفصیلات مانگتا ہے',
  'step.forms_none': 'سائن اِن یا ادائیگی کا کوئی فارم نہیں',
  'step.picture': 'صفحے کی تصویر لی جا رہی ہے',
  'step.picture_done': 'تصویر لے لی گئی',
  'step.picture_none': 'کوئی تصویر نہیں لی جا سکی',

  // Errors
  'error.invalid_url': 'یہ ایسا لنک نہیں جسے ہم جانچ سکیں',
  'error.only_web': 'صرف ویب لنک جانچے جا سکتے ہیں',
  'error.unauthorized': 'ایپ کا یہ ورژن اب سروس استعمال نہیں کر سکتا۔ SecureQR اپ ڈیٹ کریں اور دوبارہ کوشش کریں۔',
  'error.busy': 'سروس مصروف ہے۔ تھوڑی دیر بعد دوبارہ کوشش کریں',
  'error.too_many': 'بہت زیادہ اسکین۔ ایک منٹ انتظار کریں اور دوبارہ کوشش کریں',
  'error.not_found_site': 'یہ سائٹ نہیں ملی',
  'error.timeout': 'صفحہ لوڈ ہونے میں بہت دیر لگی',
  'error.bad_certificate': 'سائٹ کا سیکیورٹی سرٹیفکیٹ خراب ہے',
  'error.no_response': 'سائٹ نے جواب نہیں دیا',
  'error.private_network': 'یہ لنک ایک نجی نیٹ ورک کے پتے کی طرف جاتا ہے، اس لیے اس کا پیش منظر نہیں دکھایا جا سکتا',
  'error.internal': 'ہماری طرف کچھ غلط ہو گیا',
  'error.not_found': 'نہیں ملا',
  'error.expired': 'اس پیش منظر کی میعاد ختم ہو گئی ہے',
};
export default messages;
