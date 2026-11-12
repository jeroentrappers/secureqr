// Tamil
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} தீங்கானது எனப் பட்டியலிட்டுள்ளன',
  'reason.download': 'இந்த இணைப்பு ஒரு கோப்பைப் பதிவிறக்க முயன்றது',
  'reason.not_https': 'இறுதிப் பக்கம் என்க்ரிப்ட் செய்யப்படவில்லை',
  'reason.ip_address': 'முகவரி பெயர் அல்ல, வெறும் எண்',
  'reason.lookalike_domain': 'முகவரி ஒன்றைப் போலவே தோன்றும் எழுத்துகளைப் பயன்படுத்துகிறது',
  'reason.embedded_credentials': 'இணைப்பு முகவரிக்குள் ஒரு உள்நுழைவுப் பெயரை மறைக்கிறது',
  'reason.domain_changed': 'தொடங்கிய தளத்தை விட்டு வேறு தளத்தில் முடிகிறது',
  'reason.opens_app': 'இந்த இணைப்பு வேறொரு ஆப்பைத் திறக்க முயல்கிறது ({scheme})',
  'reason.asks_for_payment': 'பக்கம் கார்டு விவரங்களைக் கேட்கிறது',
  'reason.asks_for_password': 'பக்கம் கடவுச்சொல்லைக் கேட்கிறது',
  'reason.many_redirects': { one: '{count} திசைதிருப்பல் வழியாகச் சென்றது', other: '{count} திசைதிருப்பல்கள் வழியாகச் சென்றது' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'தடுப்புப் பட்டியல்கள் சரிபார்ப்பு',
  'step.listed': '{providers} தீங்கானது எனப் பட்டியலிட்டுள்ளன',
  'step.not_listed': { one: 'தடுப்புப் பட்டியலில் இல்லை', other: '{count} தடுப்புப் பட்டியல்களிலும் இல்லை' },
  'step.lists_unreachable': 'தடுப்புப் பட்டியல்களை அடைய முடியவில்லை',
  'step.address': 'முகவரியைத் தேடுகிறது',
  'step.address_done': 'முகவரி கிடைத்தது',
  'step.follow': 'இணைப்பைப் பின்தொடர்கிறது',
  'step.redirects': { zero: 'திசைதிருப்பல் இல்லை', one: '{count} திசைதிருப்பல்', other: '{count} திசைதிருப்பல்கள்' },
  'step.page': 'பக்கம் ஏற்றப்படுகிறது',
  'step.page_done': 'பக்கம் ஏற்றப்பட்டது',
  'step.forms': 'உள்நுழைவு, கட்டணப் படிவங்களைத் தேடுகிறது',
  'step.forms_both': 'கடவுச்சொல்லையும் கார்டு விவரங்களையும் கேட்கிறது',
  'step.forms_password': 'கடவுச்சொல்லைக் கேட்கிறது',
  'step.forms_card': 'கார்டு விவரங்களைக் கேட்கிறது',
  'step.forms_none': 'உள்நுழைவு, கட்டணப் படிவங்கள் இல்லை',
  'step.picture': 'பக்கத்தைப் படம் எடுக்கிறது',
  'step.picture_done': 'படம் எடுக்கப்பட்டது',
  'step.picture_none': 'படம் எடுக்க முடியவில்லை',

  // Errors
  'error.invalid_url': 'இதை எங்களால் சரிபார்க்க முடியாது',
  'error.only_web': 'இணைய இணைப்புகளை மட்டுமே சரிபார்க்க முடியும்',
  'error.unauthorized': 'ஆப்பின் இந்தப் பதிப்பால் இனி சேவையைப் பயன்படுத்த முடியாது. SecureQR-ஐப் புதுப்பித்து மீண்டும் முயலுங்கள்.',
  'error.busy': 'சேவை இப்போது பிஸியாக உள்ளது. சிறிது நேரம் கழித்து மீண்டும் முயலுங்கள்',
  'error.too_many': 'அதிகமான ஸ்கேன்கள். ஒரு நிமிடம் காத்திருந்து மீண்டும் முயலுங்கள்',
  'error.not_found_site': 'அந்தத் தளத்தைக் கண்டறிய முடியவில்லை',
  'error.timeout': 'பக்கம் ஏற்றப்பட அதிக நேரம் எடுத்தது',
  'error.bad_certificate': 'தளத்தின் பாதுகாப்புச் சான்றிதழ் பழுதாக உள்ளது',
  'error.no_response': 'தளம் பதிலளிக்கவில்லை',
  'error.private_network': 'இந்த இணைப்பு ஒரு தனிப்பட்ட நெட்வொர்க் முகவரியைக் குறிக்கிறது, எனவே முன்னோட்டம் காட்ட முடியாது',
  'error.internal': 'எங்கள் பக்கத்தில் ஏதோ தவறு நடந்தது',
  'error.not_found': 'கிடைக்கவில்லை',
  'error.expired': 'இந்த முன்னோட்டம் காலாவதியாகிவிட்டது',
};
export default messages;
