// 日本語
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '{providers}で危険と判定',
  'reason.download': 'リンクがファイルをダウンロードさせようとしました',
  'reason.not_https': '最終ページは暗号化されていません',
  'reason.ip_address': 'アドレスが名前ではなく数字だけです',
  'reason.lookalike_domain': 'アドレスに紛らわしい文字が使われています',
  'reason.embedded_credentials': 'アドレスの中にログイン名が隠されています',
  'reason.domain_changed': '最初とは別のサイトに行き着きます',
  'reason.opens_app': 'リンクが別のアプリを開こうとしています（{scheme}）',
  'reason.asks_for_payment': 'ページがカード情報を求めています',
  'reason.asks_for_password': 'ページがパスワードを求めています',
  'reason.many_redirects': { other: 'リダイレクトを{count}回経由しました' },

  // Progress of a check, shown while it runs
  'step.blocklists': '脅威ブロックリストを確認中',
  'step.listed': '{providers}で危険と判定',
  'step.not_listed': { other: '{count}つのブロックリストに該当なし' },
  'step.lists_unreachable': 'ブロックリストに接続できませんでした',
  'step.address': 'アドレスを照会中',
  'step.address_done': 'アドレスを確認',
  'step.follow': 'リンクをたどっています',
  'step.redirects': { zero: 'リダイレクトなし', other: 'リダイレクト{count}回' },
  'step.page': 'ページを読み込み中',
  'step.page_done': 'ページを読み込みました',
  'step.forms': 'ログイン・支払いフォームを確認中',
  'step.forms_both': 'パスワードとカード情報を要求',
  'step.forms_password': 'パスワードを要求',
  'step.forms_card': 'カード情報を要求',
  'step.forms_none': 'ログイン・支払いフォームなし',
  'step.picture': 'ページの画像を撮影中',
  'step.picture_done': '画像を撮影しました',
  'step.picture_none': '画像を撮影できませんでした',

  // Errors
  'error.invalid_url': '確認できないリンクです',
  'error.only_web': '確認できるのはWebリンクだけです',
  'error.unauthorized': 'このバージョンのアプリでは、サービスを利用できなくなりました。SecureQRをアップデートして、もう一度お試しください。',
  'error.busy': 'サービスが混み合っています。しばらくしてからもう一度お試しください',
  'error.too_many': 'スキャンの回数が多すぎます。1分ほど待ってからもう一度お試しください',
  'error.not_found_site': 'サイトが見つかりませんでした',
  'error.timeout': 'ページの読み込みに時間がかかりすぎました',
  'error.bad_certificate': 'サイトのセキュリティ証明書に問題があります',
  'error.no_response': 'サイトが応答しませんでした',
  'error.private_network': 'このリンクはプライベートネットワークのアドレスを指しているため、プレビューできません',
  'error.internal': '当社側で問題が発生しました',
  'error.not_found': '見つかりません',
  'error.expired': 'このプレビューは有効期限が切れています',
};
export default messages;
