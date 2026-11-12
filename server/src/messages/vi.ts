// Tiếng Việt
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Bị {providers} xếp vào loại độc hại',
  'reason.download': 'Link cố tải xuống một tệp',
  'reason.not_https': 'Trang cuối cùng không được mã hóa',
  'reason.ip_address': 'Địa chỉ chỉ là một dãy số, không phải tên',
  'reason.lookalike_domain': 'Địa chỉ dùng ký tự trông giống nhau',
  'reason.embedded_credentials': 'Link giấu một tên đăng nhập trong địa chỉ',
  'reason.domain_changed': 'Kết thúc ở trang khác với trang ban đầu',
  'reason.opens_app': 'Link cố mở một ứng dụng khác ({scheme})',
  'reason.asks_for_payment': 'Trang yêu cầu thông tin thẻ',
  'reason.asks_for_password': 'Trang yêu cầu mật khẩu',
  'reason.many_redirects': { other: 'Đi qua {count} lần chuyển hướng' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Đang kiểm tra danh sách chặn',
  'step.listed': 'Bị {providers} xếp vào loại độc hại',
  'step.not_listed': { other: 'Không có trong {count} danh sách chặn' },
  'step.lists_unreachable': 'Không kết nối được với danh sách chặn',
  'step.address': 'Đang tra cứu địa chỉ',
  'step.address_done': 'Đã tìm thấy địa chỉ',
  'step.follow': 'Đang đi theo link',
  'step.redirects': { zero: 'Không chuyển hướng', other: '{count} lần chuyển hướng' },
  'step.page': 'Đang tải trang',
  'step.page_done': 'Đã tải trang',
  'step.forms': 'Đang tìm biểu mẫu đăng nhập và thanh toán',
  'step.forms_both': 'Yêu cầu mật khẩu và thông tin thẻ',
  'step.forms_password': 'Yêu cầu mật khẩu',
  'step.forms_card': 'Yêu cầu thông tin thẻ',
  'step.forms_none': 'Không có biểu mẫu đăng nhập hay thanh toán',
  'step.picture': 'Đang chụp ảnh trang',
  'step.picture_done': 'Đã chụp ảnh',
  'step.picture_none': 'Không chụp được ảnh',

  // Errors
  'error.invalid_url': 'Chúng tôi không kiểm tra được link này',
  'error.only_web': 'Chỉ có thể kiểm tra link web',
  'error.unauthorized': 'Phiên bản ứng dụng này không còn dùng được dịch vụ. Hãy cập nhật SecureQR rồi thử lại.',
  'error.busy': 'Dịch vụ đang bận. Hãy thử lại sau giây lát',
  'error.too_many': 'Quá nhiều lượt quét. Hãy chờ một phút rồi thử lại',
  'error.not_found_site': 'Không tìm thấy trang web đó',
  'error.timeout': 'Trang tải quá lâu',
  'error.bad_certificate': 'Chứng chỉ bảo mật của trang web bị lỗi',
  'error.no_response': 'Trang web không phản hồi',
  'error.private_network': 'Link này trỏ đến một địa chỉ mạng riêng, nên không thể xem trước',
  'error.internal': 'Đã xảy ra lỗi ở phía chúng tôi',
  'error.not_found': 'Không tìm thấy',
  'error.expired': 'Bản xem trước này đã hết hạn',
};
export default messages;
