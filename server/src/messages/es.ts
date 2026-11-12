// Español
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Marcado como malicioso por {providers}',
  'reason.download': 'El enlace intentó descargar un archivo',
  'reason.not_https': 'La página final no está cifrada',
  'reason.ip_address': 'La dirección es un número, no un nombre',
  'reason.lookalike_domain': 'La dirección usa caracteres que imitan a otros',
  'reason.embedded_credentials': 'El enlace esconde un nombre de usuario en la dirección',
  'reason.domain_changed': 'Termina en un sitio distinto al inicial',
  'reason.opens_app': 'El enlace intenta abrir otra app ({scheme})',
  'reason.asks_for_payment': 'La página pide datos de tarjeta',
  'reason.asks_for_password': 'La página pide una contraseña',
  'reason.many_redirects': { one: 'Pasó por {count} redirección', other: 'Pasó por {count} redirecciones' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Revisando listas de bloqueo',
  'step.listed': 'Marcado como malicioso por {providers}',
  'step.not_listed': { one: 'No figura en la lista de bloqueo', other: 'No figura en {count} listas de bloqueo' },
  'step.lists_unreachable': 'No se pudo consultar las listas de bloqueo',
  'step.address': 'Buscando la dirección',
  'step.address_done': 'Dirección encontrada',
  'step.follow': 'Siguiendo el enlace',
  'step.redirects': { zero: 'Sin redirecciones', one: '{count} redirección', other: '{count} redirecciones' },
  'step.page': 'Cargando la página',
  'step.page_done': 'Página cargada',
  'step.forms': 'Buscando formularios de acceso y pago',
  'step.forms_both': 'Pide una contraseña y datos de tarjeta',
  'step.forms_password': 'Pide una contraseña',
  'step.forms_card': 'Pide datos de tarjeta',
  'step.forms_none': 'Sin formularios de acceso ni de pago',
  'step.picture': 'Tomando una imagen de la página',
  'step.picture_done': 'Imagen tomada',
  'step.picture_none': 'No se pudo tomar ninguna imagen',

  // Errors
  'error.invalid_url': 'No podemos revisar ese enlace',
  'error.only_web': 'Solo se pueden revisar enlaces web',
  'error.unauthorized': 'Esta versión de la app ya no puede usar el servicio. Actualiza SecureQR y vuelve a intentarlo.',
  'error.busy': 'El servicio está ocupado. Vuelve a intentarlo en un momento',
  'error.too_many': 'Demasiados escaneos. Espera un minuto y vuelve a intentarlo',
  'error.not_found_site': 'No se encontró ese sitio',
  'error.timeout': 'La página tardó demasiado en cargar',
  'error.bad_certificate': 'El sitio tiene un certificado de seguridad no válido',
  'error.no_response': 'El sitio no respondió',
  'error.private_network': 'Este enlace apunta a una dirección de red privada, así que no se puede previsualizar',
  'error.internal': 'Algo salió mal por nuestra parte',
  'error.not_found': 'No encontrado',
  'error.expired': 'Esta vista previa ha caducado',
};
export default messages;
