// Deutsch
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Von {providers} als schädlich gelistet',
  'reason.download': 'Der Link wollte eine Datei herunterladen',
  'reason.not_https': 'Die Zielseite ist nicht verschlüsselt',
  'reason.ip_address': 'Die Adresse ist eine bloße Zahl, kein Name',
  'reason.lookalike_domain': 'Die Adresse verwendet ähnlich aussehende Zeichen',
  'reason.embedded_credentials': 'Der Link versteckt einen Anmeldenamen in der Adresse',
  'reason.domain_changed': 'Endet auf einer anderen Website als am Anfang',
  'reason.opens_app': 'Der Link will eine andere App öffnen ({scheme})',
  'reason.asks_for_payment': 'Die Seite fragt nach Kartendaten',
  'reason.asks_for_password': 'Die Seite fragt nach einem Passwort',
  'reason.many_redirects': { one: 'Ging über {count} Weiterleitung', other: 'Ging über {count} Weiterleitungen' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Sperrlisten werden geprüft',
  'step.listed': 'Von {providers} als schädlich gelistet',
  'step.not_listed': { one: 'Nicht auf der Sperrliste', other: 'Auf keiner von {count} Sperrlisten' },
  'step.lists_unreachable': 'Sperrlisten waren nicht erreichbar',
  'step.address': 'Adresse wird gesucht',
  'step.address_done': 'Adresse gefunden',
  'step.follow': 'Link wird verfolgt',
  'step.redirects': { zero: 'Keine Weiterleitungen', one: '{count} Weiterleitung', other: '{count} Weiterleitungen' },
  'step.page': 'Seite wird geladen',
  'step.page_done': 'Seite geladen',
  'step.forms': 'Suche nach Anmelde- und Zahlungsformularen',
  'step.forms_both': 'Fragt nach Passwort und Kartendaten',
  'step.forms_password': 'Fragt nach einem Passwort',
  'step.forms_card': 'Fragt nach Kartendaten',
  'step.forms_none': 'Keine Anmelde- oder Zahlungsformulare',
  'step.picture': 'Bild der Seite wird aufgenommen',
  'step.picture_done': 'Bild aufgenommen',
  'step.picture_none': 'Es konnte kein Bild aufgenommen werden',

  // Errors
  'error.invalid_url': 'Diesen Link können wir nicht prüfen',
  'error.only_web': 'Nur Weblinks können geprüft werden',
  'error.unauthorized': 'Diese Version der App kann den Dienst nicht mehr nutzen. Aktualisieren Sie SecureQR und versuchen Sie es erneut.',
  'error.busy': 'Der Dienst ist ausgelastet. Versuchen Sie es gleich noch einmal',
  'error.too_many': 'Zu viele Scans. Warten Sie eine Minute und versuchen Sie es erneut',
  'error.not_found_site': 'Diese Website wurde nicht gefunden',
  'error.timeout': 'Die Seite hat zu lange zum Laden gebraucht',
  'error.bad_certificate': 'Die Website hat ein fehlerhaftes Sicherheitszertifikat',
  'error.no_response': 'Die Website hat nicht geantwortet',
  'error.private_network': 'Dieser Link zeigt auf eine private Netzwerkadresse und kann daher nicht angezeigt werden',
  'error.internal': 'Bei uns ist etwas schiefgelaufen',
  'error.not_found': 'Nicht gefunden',
  'error.expired': 'Diese Vorschau ist abgelaufen',
};
export default messages;
