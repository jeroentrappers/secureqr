// मराठी
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} ने धोकादायक म्हणून नोंदवले',
  'reason.download': 'लिंकने फाइल डाउनलोड करण्याचा प्रयत्न केला',
  'reason.not_https': 'शेवटचे पेज एन्क्रिप्टेड नाही',
  'reason.ip_address': 'पत्ता नावाऐवजी फक्त एक नंबर आहे',
  'reason.lookalike_domain': 'पत्त्यात सारखी दिसणारी अक्षरे वापरली आहेत',
  'reason.embedded_credentials': 'लिंक पत्त्यात लॉगिन नाव लपवते',
  'reason.domain_changed': 'सुरुवातीपेक्षा वेगळ्या साइटवर पोहोचते',
  'reason.opens_app': 'लिंक दुसरे ॲप उघडण्याचा प्रयत्न करते ({scheme})',
  'reason.asks_for_payment': 'पेज कार्ड तपशील मागत आहे',
  'reason.asks_for_password': 'पेज पासवर्ड मागत आहे',
  'reason.many_redirects': { one: '{count} रीडायरेक्टमधून गेली', other: '{count} रीडायरेक्टमधून गेली' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'धोका ब्लॉकलिस्ट तपासत आहोत',
  'step.listed': '{providers} ने धोकादायक म्हणून नोंदवले',
  'step.not_listed': { one: 'ब्लॉकलिस्टवर नाही', other: '{count} पैकी एकाही ब्लॉकलिस्टवर नाही' },
  'step.lists_unreachable': 'ब्लॉकलिस्टपर्यंत पोहोचता आले नाही',
  'step.address': 'पत्ता शोधत आहोत',
  'step.address_done': 'पत्ता सापडला',
  'step.follow': 'लिंक फॉलो करत आहोत',
  'step.redirects': { zero: 'रीडायरेक्ट नाही', one: '{count} रीडायरेक्ट', other: '{count} रीडायरेक्ट' },
  'step.page': 'पेज लोड करत आहोत',
  'step.page_done': 'पेज लोड झाले',
  'step.forms': 'साइन-इन आणि पेमेंट फॉर्म शोधत आहोत',
  'step.forms_both': 'पासवर्ड आणि कार्ड तपशील मागते',
  'step.forms_password': 'पासवर्ड मागते',
  'step.forms_card': 'कार्ड तपशील मागते',
  'step.forms_none': 'साइन-इन किंवा पेमेंट फॉर्म नाही',
  'step.picture': 'पेजचे चित्र घेत आहोत',
  'step.picture_done': 'चित्र घेतले',
  'step.picture_none': 'चित्र घेता आले नाही',

  // Errors
  'error.invalid_url': 'ही लिंक आम्ही तपासू शकत नाही',
  'error.only_web': 'फक्त वेब लिंक तपासता येतात',
  'error.unauthorized': 'ॲपची ही आवृत्ती आता सेवा वापरू शकत नाही. SecureQR अपडेट करा आणि पुन्हा प्रयत्न करा.',
  'error.busy': 'सेवा व्यस्त आहे. थोड्या वेळाने पुन्हा प्रयत्न करा',
  'error.too_many': 'खूप जास्त स्कॅन. एक मिनिट थांबा आणि पुन्हा प्रयत्न करा',
  'error.not_found_site': 'ती साइट सापडली नाही',
  'error.timeout': 'पेज लोड व्हायला खूप वेळ लागला',
  'error.bad_certificate': 'साइटचे सुरक्षा प्रमाणपत्र सदोष आहे',
  'error.no_response': 'साइटने प्रतिसाद दिला नाही',
  'error.private_network': 'ही लिंक खाजगी नेटवर्क पत्त्याकडे जाते, त्यामुळे तिचे प्रिव्ह्यू दाखवता येत नाही',
  'error.internal': 'आमच्या बाजूने काहीतरी चुकले',
  'error.not_found': 'सापडले नाही',
  'error.expired': 'या प्रिव्ह्यूची मुदत संपली आहे',
};
export default messages;
