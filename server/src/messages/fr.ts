// Français
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Signalé comme malveillant par {providers}',
  'reason.download': 'Le lien a tenté de télécharger un fichier',
  'reason.not_https': 'La page finale n’est pas chiffrée',
  'reason.ip_address': 'L’adresse est un simple numéro, pas un nom',
  'reason.lookalike_domain': 'L’adresse utilise des caractères trompeurs',
  'reason.embedded_credentials': 'Le lien cache un identifiant dans l’adresse',
  'reason.domain_changed': 'Arrive sur un autre site qu’au départ',
  'reason.opens_app': 'Le lien tente d’ouvrir une autre application ({scheme})',
  'reason.asks_for_payment': 'La page demande des données de carte',
  'reason.asks_for_password': 'La page demande un mot de passe',
  'reason.many_redirects': { one: 'Passé par {count} redirection', many: 'Passé par {count} redirections', other: 'Passé par {count} redirections' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Vérification des listes de blocage',
  'step.listed': 'Signalé comme malveillant par {providers}',
  'step.not_listed': { one: 'Absent de la liste de blocage', many: 'Absent de {count} listes de blocage', other: 'Absent de {count} listes de blocage' },
  'step.lists_unreachable': 'Listes de blocage injoignables',
  'step.address': 'Recherche de l’adresse',
  'step.address_done': 'Adresse trouvée',
  'step.follow': 'Suivi du lien',
  'step.redirects': { zero: 'Aucune redirection', one: '{count} redirection', many: '{count} redirections', other: '{count} redirections' },
  'step.page': 'Chargement de la page',
  'step.page_done': 'Page chargée',
  'step.forms': 'Recherche de formulaires de connexion et de paiement',
  'step.forms_both': 'Demande un mot de passe et des données de carte',
  'step.forms_password': 'Demande un mot de passe',
  'step.forms_card': 'Demande des données de carte',
  'step.forms_none': 'Aucun formulaire de connexion ou de paiement',
  'step.picture': 'Capture de la page',
  'step.picture_done': 'Capture effectuée',
  'step.picture_none': 'Aucune capture n’a pu être faite',

  // Errors
  'error.invalid_url': 'Nous ne pouvons pas vérifier ce lien',
  'error.only_web': 'Seuls les liens web peuvent être vérifiés',
  'error.unauthorized': 'Cette version de l’application ne peut plus utiliser le service. Mettez SecureQR à jour et réessayez.',
  'error.busy': 'Le service est surchargé. Réessayez dans un instant',
  'error.too_many': 'Trop de scans. Patientez une minute et réessayez',
  'error.not_found_site': 'Ce site est introuvable',
  'error.timeout': 'La page a mis trop de temps à charger',
  'error.bad_certificate': 'Le site a un certificat de sécurité invalide',
  'error.no_response': 'Le site n’a pas répondu',
  'error.private_network': 'Ce lien pointe vers une adresse de réseau privé, il ne peut donc pas être prévisualisé',
  'error.internal': 'Un problème est survenu de notre côté',
  'error.not_found': 'Introuvable',
  'error.expired': 'Cet aperçu a expiré',
};
export default messages;
