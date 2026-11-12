// Português (Brasil)
import type { Catalog } from './types.js';

const messages: Catalog = {
  // Por que um link recebeu seu resultado
  'reason.known_malicious': 'Marcado como perigoso por {providers}',
  'reason.download': 'O link tentou baixar um arquivo',
  'reason.not_https': 'A página final não é criptografada',
  'reason.ip_address': 'O endereço é só um número, não um nome',
  'reason.lookalike_domain': 'O endereço usa caracteres parecidos com outros',
  'reason.embedded_credentials': 'O link esconde um nome de login dentro do endereço',
  'reason.domain_changed': 'Termina em um site diferente do inicial',
  'reason.opens_app': 'O link tenta abrir outro app ({scheme})',
  'reason.asks_for_payment': 'A página pede dados do cartão',
  'reason.asks_for_password': 'A página pede uma senha',
  'reason.many_redirects': { one: 'Passou por {count} redirecionamento', other: 'Passou por {count} redirecionamentos' },

  // Andamento da verificação
  'step.blocklists': 'Verificando listas de bloqueio',
  'step.listed': 'Marcado como perigoso por {providers}',
  'step.not_listed': { one: 'Fora da lista de bloqueio', other: 'Fora de {count} listas de bloqueio' },
  'step.lists_unreachable': 'Não foi possível acessar as listas de bloqueio',
  'step.address': 'Buscando o endereço',
  'step.address_done': 'Endereço encontrado',
  'step.follow': 'Seguindo o link',
  'step.redirects': { zero: 'Sem redirecionamentos', one: '{count} redirecionamento', other: '{count} redirecionamentos' },
  'step.page': 'Carregando a página',
  'step.page_done': 'Página carregada',
  'step.forms': 'Procurando formulários de login e pagamento',
  'step.forms_both': 'Pede uma senha e dados do cartão',
  'step.forms_password': 'Pede uma senha',
  'step.forms_card': 'Pede dados do cartão',
  'step.forms_none': 'Sem formulários de login ou pagamento',
  'step.picture': 'Tirando foto da página',
  'step.picture_done': 'Foto tirada',
  'step.picture_none': 'Não foi possível tirar uma foto',

  // Erros
  'error.invalid_url': 'Não conseguimos verificar este link',
  'error.only_web': 'Só links da web podem ser verificados',
  'error.unauthorized': 'Esta versão do app não pode mais usar o serviço. Atualize o SecureQR e tente de novo.',
  'error.busy': 'O serviço está ocupado. Tente de novo daqui a pouco',
  'error.too_many': 'Leituras demais. Espere um minuto e tente de novo',
  'error.not_found_site': 'Esse site não foi encontrado',
  'error.timeout': 'A página demorou demais para carregar',
  'error.bad_certificate': 'O site tem um certificado de segurança com problema',
  'error.no_response': 'O site não respondeu',
  'error.private_network': 'Este link aponta para um endereço de rede privada, então não é possível mostrar uma prévia',
  'error.internal': 'Algo deu errado do nosso lado',
  'error.not_found': 'Não encontrado',
  'error.expired': 'Esta prévia expirou',
};
export default messages;
