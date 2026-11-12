// العربية
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'مُدرج كموقع ضار لدى {providers}',
  'reason.download': 'حاول الرابط تنزيل ملف',
  'reason.not_https': 'الصفحة الأخيرة غير مشفّرة',
  'reason.ip_address': 'العنوان رقم مجرّد، وليس اسمًا',
  'reason.lookalike_domain': 'يستخدم العنوان أحرفًا متشابهة للخداع',
  'reason.embedded_credentials': 'يخفي الرابط اسم تسجيل دخول داخل العنوان',
  'reason.domain_changed': 'ينتهي في موقع غير الذي بدأ منه',
  'reason.opens_app': 'يحاول الرابط فتح تطبيق آخر ({scheme})',
  'reason.asks_for_payment': 'الصفحة تطلب بيانات البطاقة',
  'reason.asks_for_password': 'الصفحة تطلب كلمة مرور',
  'reason.many_redirects': {
    zero: 'لم يمرّ بأي إعادة توجيه',
    one: 'مرّ بإعادة توجيه واحدة',
    two: 'مرّ بإعادتَي توجيه',
    few: 'مرّ بـ {count} عمليات إعادة توجيه',
    many: 'مرّ بـ {count} عملية إعادة توجيه',
    other: 'مرّ بـ {count} عملية إعادة توجيه',
  },

  // Progress of a check, shown while it runs
  'step.blocklists': 'فحص قوائم حظر التهديدات',
  'step.listed': 'مُدرج كموقع ضار لدى {providers}',
  'step.not_listed': {
    zero: 'غير مُدرج في أي قائمة حظر',
    one: 'غير مُدرج في قائمة الحظر',
    two: 'غير مُدرج في قائمتَي حظر',
    few: 'غير مُدرج في {count} قوائم حظر',
    many: 'غير مُدرج في {count} قائمة حظر',
    other: 'غير مُدرج في {count} قائمة حظر',
  },
  'step.lists_unreachable': 'تعذّر الوصول إلى قوائم الحظر',
  'step.address': 'البحث عن العنوان',
  'step.address_done': 'تم العثور على العنوان',
  'step.follow': 'تتبّع الرابط',
  'step.redirects': {
    zero: 'بلا إعادة توجيه',
    one: 'إعادة توجيه واحدة',
    two: 'إعادتا توجيه',
    few: '{count} عمليات إعادة توجيه',
    many: '{count} عملية إعادة توجيه',
    other: '{count} عملية إعادة توجيه',
  },
  'step.page': 'تحميل الصفحة',
  'step.page_done': 'تم تحميل الصفحة',
  'step.forms': 'البحث عن نماذج تسجيل الدخول والدفع',
  'step.forms_both': 'يطلب كلمة مرور وبيانات بطاقة',
  'step.forms_password': 'يطلب كلمة مرور',
  'step.forms_card': 'يطلب بيانات البطاقة',
  'step.forms_none': 'لا نماذج تسجيل دخول أو دفع',
  'step.picture': 'التقاط صورة للصفحة',
  'step.picture_done': 'تم التقاط الصورة',
  'step.picture_none': 'تعذّر التقاط صورة',

  // Errors
  'error.invalid_url': 'هذا ليس رابطًا يمكننا فحصه',
  'error.only_web': 'يمكن فحص روابط الويب فقط',
  'error.unauthorized': 'لم يعد بإمكان هذه النسخة من التطبيق استخدام الخدمة. حدّث SecureQR وأعد المحاولة.',
  'error.busy': 'الخدمة مشغولة. أعد المحاولة بعد قليل',
  'error.too_many': 'عمليات مسح كثيرة جدًا. انتظر دقيقة وأعد المحاولة',
  'error.not_found_site': 'تعذّر العثور على هذا الموقع',
  'error.timeout': 'استغرق تحميل الصفحة وقتًا طويلاً',
  'error.bad_certificate': 'شهادة الأمان لهذا الموقع معطوبة',
  'error.no_response': 'لم يستجب الموقع',
  'error.private_network': 'يشير هذا الرابط إلى عنوان في شبكة خاصة، لذا لا يمكن معاينته',
  'error.internal': 'حدث خطأ من جهتنا',
  'error.not_found': 'غير موجود',
  'error.expired': 'انتهت صلاحية هذه المعاينة',
};
export default messages;
