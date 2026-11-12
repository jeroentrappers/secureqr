// 한국어
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers}에서 악성으로 분류',
  'reason.download': '링크가 파일을 다운로드하려고 했어요',
  'reason.not_https': '최종 페이지가 암호화되지 않았어요',
  'reason.ip_address': '주소가 이름이 아닌 숫자로만 되어 있어요',
  'reason.lookalike_domain': '주소에 비슷하게 생긴 문자가 쓰였어요',
  'reason.embedded_credentials': '링크가 주소 안에 로그인 이름을 숨기고 있어요',
  'reason.domain_changed': '처음과 다른 사이트에서 끝나요',
  'reason.opens_app': '링크가 다른 앱을 열려고 해요({scheme})',
  'reason.asks_for_payment': '페이지가 카드 정보를 요구해요',
  'reason.asks_for_password': '페이지가 비밀번호를 요구해요',
  'reason.many_redirects': { other: '리디렉션을 {count}회 거쳤어요' },

  // Progress of a check, shown while it runs
  'step.blocklists': '위협 차단 목록 확인 중',
  'step.listed': '{providers}에서 악성으로 분류',
  'step.not_listed': { other: '차단 목록 {count}곳에 없음' },
  'step.lists_unreachable': '차단 목록에 연결할 수 없음',
  'step.address': '주소 조회 중',
  'step.address_done': '주소 찾음',
  'step.follow': '링크 따라가는 중',
  'step.redirects': { zero: '리디렉션 없음', other: '리디렉션 {count}회' },
  'step.page': '페이지 불러오는 중',
  'step.page_done': '페이지 불러옴',
  'step.forms': '로그인·결제 양식 찾는 중',
  'step.forms_both': '비밀번호와 카드 정보 요구',
  'step.forms_password': '비밀번호 요구',
  'step.forms_card': '카드 정보 요구',
  'step.forms_none': '로그인·결제 양식 없음',
  'step.picture': '페이지 사진 찍는 중',
  'step.picture_done': '사진 찍음',
  'step.picture_none': '사진을 찍을 수 없음',

  // Errors
  'error.invalid_url': '확인할 수 있는 링크가 아니에요',
  'error.only_web': '웹 링크만 확인할 수 있어요',
  'error.unauthorized': '이 버전의 앱으로는 더 이상 서비스를 이용할 수 없어요. SecureQR을 업데이트한 뒤 다시 시도하세요.',
  'error.busy': '서비스가 혼잡해요. 잠시 후 다시 시도하세요',
  'error.too_many': '스캔 횟수가 너무 많아요. 1분 정도 기다린 뒤 다시 시도하세요',
  'error.not_found_site': '사이트를 찾을 수 없어요',
  'error.timeout': '페이지를 불러오는 데 너무 오래 걸렸어요',
  'error.bad_certificate': '사이트의 보안 인증서에 문제가 있어요',
  'error.no_response': '사이트가 응답하지 않았어요',
  'error.private_network': '사설 네트워크 주소를 가리키는 링크라서 미리 볼 수 없어요',
  'error.internal': '저희 쪽에 문제가 생겼어요',
  'error.not_found': '찾을 수 없음',
  'error.expired': '이 미리보기는 만료되었어요',
};
export default messages;
