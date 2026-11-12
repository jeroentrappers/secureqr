// 简体中文
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': '被 {providers} 列为恶意',
  'reason.download': '链接试图下载文件',
  'reason.not_https': '最终页面未加密',
  'reason.ip_address': '地址是一串数字，而不是名称',
  'reason.lookalike_domain': '地址使用了形近字符',
  'reason.embedded_credentials': '链接在地址中藏了一个登录名',
  'reason.domain_changed': '最终网站与起始网站不同',
  'reason.opens_app': '链接试图打开另一个应用（{scheme}）',
  'reason.asks_for_payment': '页面索取银行卡信息',
  'reason.asks_for_password': '页面索取密码',
  'reason.many_redirects': { other: '经过了 {count} 次跳转' },

  // Progress of a check, shown while it runs
  'step.blocklists': '正在检查威胁黑名单',
  'step.listed': '被 {providers} 列为恶意',
  'step.not_listed': { other: '不在 {count} 个黑名单中' },
  'step.lists_unreachable': '无法连接黑名单服务',
  'step.address': '正在查找地址',
  'step.address_done': '已找到地址',
  'step.follow': '正在跟随链接',
  'step.redirects': { zero: '无跳转', other: '{count} 次跳转' },
  'step.page': '正在加载页面',
  'step.page_done': '页面已加载',
  'step.forms': '正在查找登录和支付表单',
  'step.forms_both': '索取密码和银行卡信息',
  'step.forms_password': '索取密码',
  'step.forms_card': '索取银行卡信息',
  'step.forms_none': '无登录或支付表单',
  'step.picture': '正在为页面截图',
  'step.picture_done': '已截图',
  'step.picture_none': '无法截图',

  // Errors
  'error.invalid_url': '这不是我们能检查的链接',
  'error.only_web': '只能检查网页链接',
  'error.unauthorized': '这个版本的应用已无法使用本服务。请更新 SecureQR 后重试。',
  'error.busy': '服务繁忙，请稍后重试',
  'error.too_many': '扫描次数太多，请等一分钟再试',
  'error.not_found_site': '找不到这个网站',
  'error.timeout': '页面加载太久',
  'error.bad_certificate': '这个网站的安全证书有问题',
  'error.no_response': '网站没有响应',
  'error.private_network': '这个链接指向私有网络地址，因此无法预览',
  'error.internal': '我们这边出了问题',
  'error.not_found': '未找到',
  'error.expired': '这个预览已过期',
};
export default messages;
