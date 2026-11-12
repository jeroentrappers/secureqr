// Russian
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'В списках вредоносных: {providers}',
  'reason.download': 'Ссылка пыталась скачать файл',
  'reason.not_https': 'Конечная страница не зашифрована',
  'reason.ip_address': 'Адрес — это просто число, а не имя',
  'reason.lookalike_domain': 'В адресе есть похожие на другие символы',
  'reason.embedded_credentials': 'Ссылка прячет имя для входа внутри адреса',
  'reason.domain_changed': 'Конечный сайт отличается от начального',
  'reason.opens_app': 'Ссылка пытается открыть другое приложение ({scheme})',
  'reason.asks_for_payment': 'Страница запрашивает данные карты',
  'reason.asks_for_password': 'Страница запрашивает пароль',
  'reason.many_redirects': {
    one: 'Прошла через {count} перенаправление',
    few: 'Прошла через {count} перенаправления',
    many: 'Прошла через {count} перенаправлений',
    other: 'Прошла через {count} перенаправления',
  },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Проверка списков угроз',
  'step.listed': 'В списках вредоносных: {providers}',
  'step.not_listed': {
    one: 'Нет в {count} списке блокировки',
    few: 'Нет в {count} списках блокировки',
    many: 'Нет в {count} списках блокировки',
    other: 'Нет в {count} списках блокировки',
  },
  'step.lists_unreachable': 'Списки блокировки недоступны',
  'step.address': 'Поиск адреса',
  'step.address_done': 'Адрес найден',
  'step.follow': 'Переход по ссылке',
  'step.redirects': {
    zero: 'Без перенаправлений',
    one: '{count} перенаправление',
    few: '{count} перенаправления',
    many: '{count} перенаправлений',
    other: '{count} перенаправления',
  },
  'step.page': 'Загрузка страницы',
  'step.page_done': 'Страница загружена',
  'step.forms': 'Поиск форм входа и оплаты',
  'step.forms_both': 'Запрашивает пароль и данные карты',
  'step.forms_password': 'Запрашивает пароль',
  'step.forms_card': 'Запрашивает данные карты',
  'step.forms_none': 'Нет форм входа или оплаты',
  'step.picture': 'Снимок страницы',
  'step.picture_done': 'Снимок готов',
  'step.picture_none': 'Не удалось сделать снимок',

  // Errors
  'error.invalid_url': 'Эту ссылку нельзя проверить',
  'error.only_web': 'Проверить можно только веб-ссылки',
  'error.unauthorized': 'Эта версия приложения больше не может пользоваться сервисом. Обновите SecureQR и попробуйте снова.',
  'error.busy': 'Сервис перегружен. Попробуйте ещё раз чуть позже',
  'error.too_many': 'Слишком много сканирований. Подождите минуту и попробуйте снова',
  'error.not_found_site': 'Сайт не найден',
  'error.timeout': 'Страница грузилась слишком долго',
  'error.bad_certificate': 'У сайта неисправный сертификат безопасности',
  'error.no_response': 'Сайт не ответил',
  'error.private_network': 'Ссылка ведёт на адрес в частной сети, поэтому её нельзя просмотреть',
  'error.internal': 'У нас что-то пошло не так',
  'error.not_found': 'Не найдено',
  'error.expired': 'Срок этого просмотра истёк',
};
export default messages;
