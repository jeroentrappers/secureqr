// हिन्दी
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} ने ख़तरनाक बताया',
  'reason.download': 'लिंक ने एक फ़ाइल डाउनलोड करने की कोशिश की',
  'reason.not_https': 'आख़िरी पेज एन्क्रिप्टेड नहीं है',
  'reason.ip_address': 'पता कोई नाम नहीं, सिर्फ़ एक नंबर है',
  'reason.lookalike_domain': 'पते में मिलते-जुलते दिखने वाले अक्षर हैं',
  'reason.embedded_credentials': 'लिंक पते के अंदर एक लॉगिन नाम छिपाता है',
  'reason.domain_changed': 'शुरुआत से अलग साइट पर ख़त्म होता है',
  'reason.opens_app': 'लिंक कोई दूसरा ऐप खोलने की कोशिश करता है ({scheme})',
  'reason.asks_for_payment': 'पेज कार्ड की जानकारी माँगता है',
  'reason.asks_for_password': 'पेज पासवर्ड माँगता है',
  'reason.many_redirects': { one: '{count} रीडायरेक्ट से होकर गुज़रा', other: '{count} रीडायरेक्ट से होकर गुज़रा' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'ख़तरा ब्लॉकलिस्ट जाँच रहे हैं',
  'step.listed': '{providers} ने ख़तरनाक बताया',
  'step.not_listed': { one: 'ब्लॉकलिस्ट में नहीं', other: '{count} ब्लॉकलिस्ट में नहीं' },
  'step.lists_unreachable': 'ब्लॉकलिस्ट तक पहुँचा नहीं जा सका',
  'step.address': 'पता खोज रहे हैं',
  'step.address_done': 'पता मिल गया',
  'step.follow': 'लिंक फ़ॉलो कर रहे हैं',
  'step.redirects': { zero: 'कोई रीडायरेक्ट नहीं', one: '{count} रीडायरेक्ट', other: '{count} रीडायरेक्ट' },
  'step.page': 'पेज लोड हो रहा है',
  'step.page_done': 'पेज लोड हो गया',
  'step.forms': 'साइन-इन और भुगतान फ़ॉर्म खोज रहे हैं',
  'step.forms_both': 'पासवर्ड और कार्ड की जानकारी माँगता है',
  'step.forms_password': 'पासवर्ड माँगता है',
  'step.forms_card': 'कार्ड की जानकारी माँगता है',
  'step.forms_none': 'कोई साइन-इन या भुगतान फ़ॉर्म नहीं',
  'step.picture': 'पेज की तस्वीर ले रहे हैं',
  'step.picture_done': 'तस्वीर ले ली गई',
  'step.picture_none': 'कोई तस्वीर नहीं ली जा सकी',

  // Errors
  'error.invalid_url': 'इस लिंक की जाँच हम नहीं कर सकते',
  'error.only_web': 'सिर्फ़ वेब लिंक की जाँच हो सकती है',
  'error.unauthorized': 'ऐप का यह संस्करण अब सेवा का इस्तेमाल नहीं कर सकता। SecureQR अपडेट करें और फिर से कोशिश करें।',
  'error.busy': 'सेवा अभी व्यस्त है। थोड़ी देर में फिर से कोशिश करें',
  'error.too_many': 'बहुत ज़्यादा स्कैन। एक मिनट रुकें और फिर से कोशिश करें',
  'error.not_found_site': 'वह साइट नहीं मिली',
  'error.timeout': 'पेज लोड होने में बहुत समय लगा',
  'error.bad_certificate': 'साइट का सुरक्षा सर्टिफ़िकेट ख़राब है',
  'error.no_response': 'साइट ने जवाब नहीं दिया',
  'error.private_network': 'यह लिंक एक निजी नेटवर्क पते की ओर जाता है, इसलिए इसका प्रीव्यू नहीं दिखाया जा सकता',
  'error.internal': 'हमारी तरफ़ से कुछ गड़बड़ हो गई',
  'error.not_found': 'नहीं मिला',
  'error.expired': 'इस प्रीव्यू की समय-सीमा ख़त्म हो गई है',
};
export default messages;
