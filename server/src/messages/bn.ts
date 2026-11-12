// বাংলা (Bengali)
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} একে ক্ষতিকর বলে চিহ্নিত করেছে',
  'reason.download': 'লিংকটি একটি ফাইল ডাউনলোড করানোর চেষ্টা করেছে',
  'reason.not_https': 'শেষ পেজটি এনক্রিপ্ট করা নয়',
  'reason.ip_address': 'ঠিকানাটি শুধু একটি সংখ্যা, কোনো নাম নয়',
  'reason.lookalike_domain': 'ঠিকানায় দেখতে একই রকম অক্ষর ব্যবহার করা হয়েছে',
  'reason.embedded_credentials': 'লিংকটি ঠিকানার ভেতরে একটি লগইন নাম লুকিয়ে রেখেছে',
  'reason.domain_changed': 'শুরু এক সাইটে, শেষ অন্য সাইটে',
  'reason.opens_app': 'লিংকটি অন্য একটি অ্যাপ খোলার চেষ্টা করে ({scheme})',
  'reason.asks_for_payment': 'পেজটি কার্ডের তথ্য চায়',
  'reason.asks_for_password': 'পেজটি পাসওয়ার্ড চায়',
  'reason.many_redirects': { one: '{count}টি রিডাইরেক্ট পার হয়েছে', other: '{count}টি রিডাইরেক্ট পার হয়েছে' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'ব্লকলিস্ট যাচাই করা হচ্ছে',
  'step.listed': '{providers} একে ক্ষতিকর বলে চিহ্নিত করেছে',
  'step.not_listed': { one: 'ব্লকলিস্টে নেই', other: '{count}টি ব্লকলিস্টে নেই' },
  'step.lists_unreachable': 'ব্লকলিস্টের সাথে যোগাযোগ করা যায়নি',
  'step.address': 'ঠিকানা খোঁজা হচ্ছে',
  'step.address_done': 'ঠিকানা পাওয়া গেছে',
  'step.follow': 'লিংক অনুসরণ করা হচ্ছে',
  'step.redirects': { zero: 'কোনো রিডাইরেক্ট নেই', one: '{count}টি রিডাইরেক্ট', other: '{count}টি রিডাইরেক্ট' },
  'step.page': 'পেজ লোড হচ্ছে',
  'step.page_done': 'পেজ লোড হয়েছে',
  'step.forms': 'সাইন-ইন ও পেমেন্ট ফর্ম খোঁজা হচ্ছে',
  'step.forms_both': 'পাসওয়ার্ড ও কার্ডের তথ্য চায়',
  'step.forms_password': 'পাসওয়ার্ড চায়',
  'step.forms_card': 'কার্ডের তথ্য চায়',
  'step.forms_none': 'সাইন-ইন বা পেমেন্ট ফর্ম নেই',
  'step.picture': 'পেজের ছবি তোলা হচ্ছে',
  'step.picture_done': 'ছবি তোলা হয়েছে',
  'step.picture_none': 'কোনো ছবি তোলা যায়নি',

  // Errors
  'error.invalid_url': 'এই লিংকটি আমরা যাচাই করতে পারি না',
  'error.only_web': 'শুধু ওয়েব লিংক যাচাই করা যায়',
  'error.unauthorized': 'অ্যাপের এই সংস্করণ দিয়ে আর সেবাটি ব্যবহার করা যাবে না। SecureQR আপডেট করে আবার চেষ্টা করুন।',
  'error.busy': 'সেবাটি এখন ব্যস্ত। একটু পরে আবার চেষ্টা করুন',
  'error.too_many': 'অনেক বেশি স্ক্যান। এক মিনিট অপেক্ষা করে আবার চেষ্টা করুন',
  'error.not_found_site': 'সাইটটি খুঁজে পাওয়া যায়নি',
  'error.timeout': 'পেজটি লোড হতে অনেক বেশি সময় লেগেছে',
  'error.bad_certificate': 'সাইটটির নিরাপত্তা সার্টিফিকেটে সমস্যা আছে',
  'error.no_response': 'সাইটটি সাড়া দেয়নি',
  'error.private_network': 'এই লিংকটি একটি প্রাইভেট নেটওয়ার্ক ঠিকানার দিকে, তাই এর প্রিভিউ দেখানো যাবে না',
  'error.internal': 'আমাদের দিকে কিছু একটা ভুল হয়েছে',
  'error.not_found': 'পাওয়া যায়নি',
  'error.expired': 'এই প্রিভিউয়ের মেয়াদ শেষ হয়ে গেছে',
};
export default messages;
