// Telugu
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers} ప్రమాదకరమైనదిగా గుర్తించాయి',
  'reason.download': 'లింక్ ఫైల్‌ను డౌన్‌లోడ్ చేయించడానికి ప్రయత్నించింది',
  'reason.not_https': 'చివరి పేజీ ఎన్‌క్రిప్ట్ కాలేదు',
  'reason.ip_address': 'చిరునామా పేరు కాదు, కేవలం ఒక సంఖ్య',
  'reason.lookalike_domain': 'చిరునామా ఒకేలా కనిపించే అక్షరాలను వాడుతోంది',
  'reason.embedded_credentials': 'లింక్ చిరునామాలో లాగిన్ పేరును దాచిపెడుతోంది',
  'reason.domain_changed': 'మొదలైన సైట్ కాకుండా వేరే సైట్‌లో ముగుస్తుంది',
  'reason.opens_app': 'లింక్ మరో యాప్‌ను తెరవడానికి ప్రయత్నిస్తోంది ({scheme})',
  'reason.asks_for_payment': 'పేజీ కార్డ్ వివరాలు అడుగుతోంది',
  'reason.asks_for_password': 'పేజీ పాస్‌వర్డ్ అడుగుతోంది',
  'reason.many_redirects': { one: '{count} రీడైరెక్ట్ గుండా వెళ్లింది', other: '{count} రీడైరెక్ట్‌ల గుండా వెళ్లింది' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'ముప్పు బ్లాక్‌లిస్ట్‌లను తనిఖీ చేస్తోంది',
  'step.listed': '{providers} ప్రమాదకరమైనదిగా గుర్తించాయి',
  'step.not_listed': { one: 'బ్లాక్‌లిస్ట్‌లో లేదు', other: '{count} బ్లాక్‌లిస్ట్‌లలో దేనిలోనూ లేదు' },
  'step.lists_unreachable': 'బ్లాక్‌లిస్ట్‌లను చేరుకోలేకపోయాం',
  'step.address': 'చిరునామాను వెతుకుతోంది',
  'step.address_done': 'చిరునామా దొరికింది',
  'step.follow': 'లింక్‌ను అనుసరిస్తోంది',
  'step.redirects': { zero: 'రీడైరెక్ట్‌లు లేవు', one: '{count} రీడైరెక్ట్', other: '{count} రీడైరెక్ట్‌లు' },
  'step.page': 'పేజీ లోడ్ అవుతోంది',
  'step.page_done': 'పేజీ లోడ్ అయింది',
  'step.forms': 'సైన్-ఇన్, చెల్లింపు ఫారమ్‌ల కోసం చూస్తోంది',
  'step.forms_both': 'పాస్‌వర్డ్, కార్డ్ వివరాలు అడుగుతుంది',
  'step.forms_password': 'పాస్‌వర్డ్ అడుగుతుంది',
  'step.forms_card': 'కార్డ్ వివరాలు అడుగుతుంది',
  'step.forms_none': 'సైన్-ఇన్ లేదా చెల్లింపు ఫారమ్‌లు లేవు',
  'step.picture': 'పేజీ చిత్రం తీస్తోంది',
  'step.picture_done': 'చిత్రం తీయబడింది',
  'step.picture_none': 'చిత్రం తీయలేకపోయాం',

  // Errors
  'error.invalid_url': 'ఇది మేము తనిఖీ చేయగల లింక్ కాదు',
  'error.only_web': 'వెబ్ లింక్‌లను మాత్రమే తనిఖీ చేయగలం',
  'error.unauthorized': 'యాప్ యొక్క ఈ వెర్షన్ ఇకపై సేవను ఉపయోగించలేదు. SecureQRని అప్‌డేట్ చేసి మళ్లీ ప్రయత్నించండి.',
  'error.busy': 'సేవ ప్రస్తుతం బిజీగా ఉంది. కాసేపట్లో మళ్లీ ప్రయత్నించండి',
  'error.too_many': 'చాలా ఎక్కువ స్కాన్‌లు. ఒక నిమిషం ఆగి మళ్లీ ప్రయత్నించండి',
  'error.not_found_site': 'ఆ సైట్ కనిపించలేదు',
  'error.timeout': 'పేజీ లోడ్ కావడానికి చాలా సమయం పట్టింది',
  'error.bad_certificate': 'ఈ సైట్ భద్రతా సర్టిఫికెట్ సరిగా లేదు',
  'error.no_response': 'సైట్ స్పందించలేదు',
  'error.private_network': 'ఈ లింక్ ప్రైవేట్ నెట్‌వర్క్ చిరునామాను సూచిస్తోంది, కాబట్టి దీన్ని ముందుగా చూపించలేం',
  'error.internal': 'మా వైపు ఏదో పొరపాటు జరిగింది',
  'error.not_found': 'కనిపించలేదు',
  'error.expired': 'ఈ ప్రివ్యూ గడువు ముగిసింది',
};
export default messages;
