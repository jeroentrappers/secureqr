// Italiano
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Why a link got its verdict
  'reason.known_malicious': 'Segnalato come dannoso da {providers}',
  'reason.download': 'Il link ha cercato di scaricare un file',
  'reason.not_https': 'La pagina finale non è cifrata',
  'reason.ip_address': "L'indirizzo è un semplice numero, non un nome",
  'reason.lookalike_domain': "L'indirizzo usa caratteri che ne imitano altri",
  'reason.embedded_credentials': "Il link nasconde un nome utente nell'indirizzo",
  'reason.domain_changed': 'Finisce su un sito diverso da quello di partenza',
  'reason.opens_app': "Il link cerca di aprire un'altra app ({scheme})",
  'reason.asks_for_payment': 'La pagina chiede i dati della carta',
  'reason.asks_for_password': 'La pagina chiede una password',
  'reason.many_redirects': { one: 'È passato per {count} reindirizzamento', other: 'È passato per {count} reindirizzamenti' },

  // Progress of a check, shown while it runs
  'step.blocklists': 'Controllo le liste di blocco',
  'step.listed': 'Segnalato come dannoso da {providers}',
  'step.not_listed': { one: 'Assente dalla lista di blocco', other: 'Assente da {count} liste di blocco' },
  'step.lists_unreachable': 'Impossibile raggiungere le liste di blocco',
  'step.address': "Cerco l'indirizzo",
  'step.address_done': 'Indirizzo trovato',
  'step.follow': 'Seguo il link',
  'step.redirects': { zero: 'Nessun reindirizzamento', one: '{count} reindirizzamento', other: '{count} reindirizzamenti' },
  'step.page': 'Carico la pagina',
  'step.page_done': 'Pagina caricata',
  'step.forms': 'Cerco moduli di accesso e pagamento',
  'step.forms_both': 'Chiede una password e i dati della carta',
  'step.forms_password': 'Chiede una password',
  'step.forms_card': 'Chiede i dati della carta',
  'step.forms_none': 'Nessun modulo di accesso o pagamento',
  'step.picture': "Scatto un'immagine della pagina",
  'step.picture_done': 'Immagine scattata',
  'step.picture_none': "Impossibile scattare un'immagine",

  // Errors
  'error.invalid_url': 'Non è un link che possiamo controllare',
  'error.only_web': 'Si possono controllare solo i link web',
  'error.unauthorized': "Questa versione dell'app non può più usare il servizio. Aggiorna SecureQR e riprova.",
  'error.busy': 'Il servizio è occupato. Riprova tra poco',
  'error.too_many': 'Troppe scansioni. Aspetta un minuto e riprova',
  'error.not_found_site': 'Impossibile trovare quel sito',
  'error.timeout': 'La pagina ci ha messo troppo a caricarsi',
  'error.bad_certificate': 'Il sito ha un certificato di sicurezza non valido',
  'error.no_response': 'Il sito non ha risposto',
  'error.private_network': "Questo link punta a un indirizzo di rete privata, quindi non è possibile un'anteprima",
  'error.internal': 'Qualcosa è andato storto da parte nostra',
  'error.not_found': 'Non trovato',
  'error.expired': "Questa anteprima è scaduta",
};
export default messages;
