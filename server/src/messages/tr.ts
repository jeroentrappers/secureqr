// Türkçe
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Bir bağlantının sonucu neden bu
  'reason.known_malicious': '{providers} tarafından zararlı olarak listelenmiş',
  'reason.download': 'Bağlantı bir dosya indirmeye çalıştı',
  'reason.not_https': 'Son sayfa şifrelenmemiş',
  'reason.ip_address': 'Adres bir ad değil, yalnızca bir sayı',
  'reason.lookalike_domain': 'Adres benzer görünen karakterler kullanıyor',
  'reason.embedded_credentials': 'Bağlantı, adresin içinde bir kullanıcı adı gizliyor',
  'reason.domain_changed': 'Başladığı siteden farklı bir sitede bitiyor',
  'reason.opens_app': 'Bağlantı başka bir uygulamayı açmaya çalışıyor ({scheme})',
  'reason.asks_for_payment': 'Sayfa kart bilgisi istiyor',
  'reason.asks_for_password': 'Sayfa şifre istiyor',
  'reason.many_redirects': { other: '{count} yönlendirmeden geçti' },

  // Kontrol sırasında gösterilen adımlar
  'step.blocklists': 'Tehdit engel listeleri kontrol ediliyor',
  'step.listed': '{providers} tarafından zararlı olarak listelenmiş',
  'step.not_listed': { one: 'Engel listesinde yok', other: '{count} engel listesinde yok' },
  'step.lists_unreachable': 'Engel listelerine ulaşılamadı',
  'step.address': 'Adres aranıyor',
  'step.address_done': 'Adres bulundu',
  'step.follow': 'Bağlantı takip ediliyor',
  'step.redirects': { zero: 'Yönlendirme yok', other: '{count} yönlendirme' },
  'step.page': 'Sayfa yükleniyor',
  'step.page_done': 'Sayfa yüklendi',
  'step.forms': 'Giriş ve ödeme formları aranıyor',
  'step.forms_both': 'Şifre ve kart bilgisi istiyor',
  'step.forms_password': 'Şifre istiyor',
  'step.forms_card': 'Kart bilgisi istiyor',
  'step.forms_none': 'Giriş veya ödeme formu yok',
  'step.picture': 'Sayfanın resmi çekiliyor',
  'step.picture_done': 'Resim çekildi',
  'step.picture_none': 'Resim çekilemedi',

  // Hatalar
  'error.invalid_url': 'Bu, kontrol edebileceğimiz bir bağlantı değil',
  'error.only_web': 'Yalnızca web bağlantıları kontrol edilebilir',
  'error.unauthorized': 'Uygulamanın bu sürümü artık hizmeti kullanamıyor. SecureQR\'ı güncelleyip tekrar deneyin.',
  'error.busy': 'Hizmet şu anda yoğun. Biraz sonra tekrar deneyin',
  'error.too_many': 'Çok fazla tarama. Bir dakika bekleyip tekrar deneyin',
  'error.not_found_site': 'Bu site bulunamadı',
  'error.timeout': 'Sayfanın yüklenmesi çok uzun sürdü',
  'error.bad_certificate': 'Sitenin güvenlik sertifikası bozuk',
  'error.no_response': 'Site yanıt vermedi',
  'error.private_network': 'Bu bağlantı özel bir ağ adresine gidiyor, bu yüzden önizlenemiyor',
  'error.internal': 'Bizim tarafımızda bir sorun oluştu',
  'error.not_found': 'Bulunamadı',
  'error.expired': 'Bu önizlemenin süresi doldu',
};
export default messages;
