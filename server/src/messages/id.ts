// Bahasa Indonesia
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Ditandai berbahaya oleh {providers}',
  'reason.download': 'Tautan mencoba mengunduh file',
  'reason.not_https': 'Halaman akhirnya tidak terenkripsi',
  'reason.ip_address': 'Alamatnya hanya berupa angka, bukan nama',
  'reason.lookalike_domain': 'Alamatnya memakai karakter yang mirip',
  'reason.embedded_credentials': 'Tautan menyembunyikan nama login di dalam alamat',
  'reason.domain_changed': 'Berakhir di situs yang berbeda dari awalnya',
  'reason.opens_app': 'Tautan mencoba membuka aplikasi lain ({scheme})',
  'reason.asks_for_payment': 'Halaman meminta data kartu',
  'reason.asks_for_password': 'Halaman meminta kata sandi',
  'reason.many_redirects': { other: 'Melewati {count} pengalihan' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Memeriksa daftar blokir',
  'step.listed': 'Ditandai berbahaya oleh {providers}',
  'step.not_listed': { other: 'Tidak ada di {count} daftar blokir' },
  'step.lists_unreachable': 'Daftar blokir tidak dapat dihubungi',
  'step.address': 'Mencari alamat',
  'step.address_done': 'Alamat ditemukan',
  'step.follow': 'Mengikuti tautan',
  'step.redirects': { zero: 'Tanpa pengalihan', other: '{count} pengalihan' },
  'step.page': 'Memuat halaman',
  'step.page_done': 'Halaman dimuat',
  'step.forms': 'Mencari formulir masuk dan pembayaran',
  'step.forms_both': 'Meminta kata sandi dan data kartu',
  'step.forms_password': 'Meminta kata sandi',
  'step.forms_card': 'Meminta data kartu',
  'step.forms_none': 'Tanpa formulir masuk atau pembayaran',
  'step.picture': 'Mengambil gambar halaman',
  'step.picture_done': 'Gambar diambil',
  'step.picture_none': 'Gambar tidak dapat diambil',

  // Errors
  'error.invalid_url': 'Itu bukan tautan yang bisa kami periksa',
  'error.only_web': 'Hanya tautan web yang bisa diperiksa',
  'error.unauthorized': 'Versi aplikasi ini tidak bisa lagi memakai layanan. Perbarui SecureQR, lalu coba lagi.',
  'error.busy': 'Layanan sedang sibuk. Coba lagi sebentar lagi',
  'error.too_many': 'Terlalu banyak pindaian. Tunggu semenit, lalu coba lagi',
  'error.not_found_site': 'Situs itu tidak ditemukan',
  'error.timeout': 'Halaman terlalu lama dimuat',
  'error.bad_certificate': 'Sertifikat keamanan situs ini rusak',
  'error.no_response': 'Situs tidak merespons',
  'error.private_network': 'Tautan ini mengarah ke alamat jaringan pribadi, jadi tidak dapat dipratinjau',
  'error.internal': 'Terjadi masalah di pihak kami',
  'error.not_found': 'Tidak ditemukan',
  'error.expired': 'Pratinjau ini sudah kedaluwarsa',
};
export default messages;
