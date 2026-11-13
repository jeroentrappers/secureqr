# Threat-intelligence sources for the preview server

Survey of free and open sources that could raise the detection rate of the
reputation check in `server/src/reputation.ts`. State of the world checked on
12 November 2026. Every licence or terms claim links to the provider's own
page; anything that could not be confirmed there is marked **unverified**.

Today the server uses four keyless sources: Quad9, Cloudflare 1.1.1.2, DNS4EU
protective, and the Phishing.Database active-domains list.

What a source has to satisfy:

- Terms that allow this use. SecureQR is free: no price, no ads, no in-app
  purchases, no account, MIT-licensed source. It is published and run by
  Appmire CommV, a company, and carries its name. Many terms count use by or
  for a company as commercial whatever the price, so each source is judged on
  its own wording (see "Free and open source: what changes").
- Anonymous lookups. A host name to a DNS resolver is fine, a full URL to a
  third party is a real cost, a list checked locally is best.
- Useful for Belgium and the EU: bank phishing, itsme, bpost and parcel
  smishing, fake parking and EV-charger payment pages.
- Fits one small server: memory and download size count.
- Answers within the per-host budget (about 2.5 s).

## Summary

Four findings change the picture more than any new source does:

1. **Phishing.Database stopped updating on 2 October 2026.** The file the
   server downloads (`phishing-domains-ACTIVE.txt`) has had no commit since
   then, although the repository is not archived and issues are still being
   filed. In a sample of 50 hosts from the list, 20 no longer resolve. None of
   the 783 hosts submitted to PhishTank in the last seven days are on it. The list
   is now a slowly decaying snapshot.
2. **The keyless abuse.ch downloads are gone.** The URLhaus and ThreatFox host
   files and text dumps answer `410 Gone` without an Auth-Key, and the terms
   (updated 21 October 2026) say commercial use of URLhaus and ThreatFox "may
   require a paid subscription" through Spamhaus.
3. **The three DNS resolvers already catch what the public feeds publish.** In
   a small test (below) every still-resolving host from OpenPhish and CERT
   Polska was blocked by at least one of Quad9, Cloudflare or DNS4EU, and no
   other free resolver added a single host. More public feeds will mostly
   duplicate the resolvers. The lift has to come from sources with their own
   detection, from Belgian data, and from signals that do not depend on
   someone having reported the site.
4. **DNS4EU's terms exclude the way the server uses it.** The terms of use
   (1 June 2025) make the service available "to individuals free of charge,
   strictly for their use in a personal capacity" and state "The Service is
   not eligible for enterprises or connectivity providers." A preview server
   run by a company is neither an individual nor personal use, price or no
   price. DNS4EU is the strongest of the three resolvers in the test.

### Ranked shortlist

| # | Candidate | Why |
|---|---|---|
| 1 | Staleness check on every downloaded list, and replace or supplement Phishing.Database | The one list in use has been frozen for six weeks and nothing noticed. |
| 2 | Settle DNS4EU: ask Whalebone (contact@joindns4.eu) or stop using it | Its terms exclude enterprises. It is the best of the three resolvers in use: on the test sample it alone caught 16 of 65 live OpenPhish hosts. |
| 3 | CERT Polska warning list | Only national CERT list with an explicit "any purpose, including commercial" policy. 124,551 domains, 2.6 MB, refreshed every 5 minutes. Keyless. |
| 4 | PhishDestroy destroylist | MIT licence, own detection (ads, search results, CT logs, typosquats), 238,144 domains, hourly. Overlaps under 5% with the other lists measured. |
| 5 | Google Safe Browsing v5, after asking Google | Its terms define commercial as "for sale or revenue-generating purposes", which a free, ad-free app arguably is not. Local-list mode sends Google nothing per lookup. If Google says no, Web Risk is the paid fallback. |
| 6 | Domain age as a caution signal (RDAP) | Does not depend on anyone reporting the site. RDAP covers `.com`, `.nl`, `.fr` and most gTLDs. `.be` only through WHOIS, whose terms forbid automated use: ask DNS Belgium first. |
| 7 | Hagezi Threat Intelligence Feeds, medium | 373,421 domains, 6.9 MB, daily. Aggregates about 20 feeds. GPL-3.0, which puts no obligation on the server when the list is only downloaded and queried. More French and German coverage than anything else measured. |
| 8 | Context lists: URL shorteners, dynamic DNS, free hosting, plus the CrUX top-sites list | Small. CrUX is CC BY 4.0 (attribution only). Turn "unknown host" into "unknown host on a free subdomain service", and hold back false alarms on popular sites. |
| 9 | Ask the CCB for access to the Belgian Anti-Phishing Shield list | Not published. It is the best Belgian data there is. A direct request costs an e-mail. |

More resolvers (Control D, AdGuard, CIRA, OpenDNS) would be easy to add with
the existing code, but measured no gain over the current three, and on a
second reading of their terms none is clearly open to a company's server
(AdGuard's EULA forbids automated requests; Control D lists datacenter use as
a termination ground; CIRA is for Canadian households). Drop them.

## Free and open source: what changes

The first version of this survey assumed a paid product. SecureQR is free,
ad-free and MIT-licensed, but it is published and run by Appmire CommV. That
helps with terms that define commercial by money ("for sale or
revenue-generating purposes", "products or services for which a fee is
charged", "commercial advantage or monetary compensation"). It does not help
with terms that look at who uses the source: "individuals ... in a personal
capacity", "your own personal use", "for parents, not organizations",
"business functions of any organization", "companies ... with commercial or
for-profit needs". Under those, a company operating a public service is
excluded whatever the price. The app also carries the company name, so a
provider can reasonably argue an indirect commercial advantage.

Outcome per source, after re-reading each provider's terms:

| Source | Deciding wording | Free MIT app run by a company |
|---|---|---|
| CERT Polska list | "may be used by any user for any purpose, including commercial purposes" | clearly allowed; do not imply endorsement |
| Phishing.Database, PhishDestroy | MIT | clearly allowed |
| Hagezi TIF and context lists, uBlock badware | GPL-3.0; "has to accompany any redistribution" | allowed; nothing is redistributed (see below) |
| CrUX | "licensed under a Creative Commons Attribution 4.0 International License" | clearly allowed, with attribution |
| Quad9 | "completely free for everyone"; no terms of service published | allowed as far as published; **unverified** |
| Cloudflare 1.1.1.2 | governed by the privacy policy; Families "designed to help individuals protect their home networks" | ambiguous, leaning allowed |
| Google Safe Browsing | "non-commercial use only", commercial meaning "for sale or revenue-generating purposes" | ambiguous, leaning allowed; ask Google |
| Cloudflare Radar (and Tranco through it) | CC BY-NC 4.0: "not primarily intended for or directed towards commercial advantage or monetary compensation" | ambiguous; the company name on the app is the weak point |
| Spamhaus DBL | "non-commercial use by small and medium sized organisations" | ambiguous; ask Spamhaus |
| abuse.ch | "for not-for-profit purposes"; paid for "companies ... with commercial or for-profit needs" | ambiguous; ask abuse.ch |
| VirusTotal public API | "must not be used in commercial products or services" | ambiguous on wording; excluded in practice by the 500/day quota |
| PhishStats | "lawful security research, threat intelligence, and related purposes"; no redistribution of raw feeds | ambiguous; quota too small anyway |
| SURBL | free for organisations "that have fewer than 1,000 users"; software developers with 1,000 or more users "MAY NOT" | allowed only while the app has fewer than 1,000 users |
| PhishTank (Cisco General Terms) | use "for Your direct benefit"; may not "provide the functionality of any ... Cloud Services ... to any third party" | leaning excluded; ask Cisco Talos |
| OpenDNS | archived terms: not "for the benefit of any third parties"; current free-service terms not found | leaning excluded; **unverified** |
| Control D free | termination for "using Control D in a datacenter environment" | leaning excluded |
| CIRA Canadian Shield | individuals and families residing in Canada (secondary source) | leaning excluded; **unverified** |
| DNS4EU | "strictly for their use in a personal capacity"; "not eligible for enterprises" | clearly excluded |
| OpenPhish | "solely for your personal use"; no use for "detection ... customer protection, or other business functions of any organization" | clearly excluded |
| Phishing Army | inherits OpenPhish and PhishTank terms | excluded through OpenPhish |
| urlscan.io | "provided only for your own personal use"; "Commercial use of any part of our service requires express written permission" | clearly excluded, measurement included, unless urlscan agrees |
| CleanBrowsing | free tier "for parents, not organizations"; no automated queries | clearly excluded |
| AdGuard DNS | EULA section 4: no "automated agents or inject scripts" generating automated requests | excluded |
| IPQS | free access counts as "evaluation, testing, trial"; no republishing "API responses ... to any third-party" | excluded for production |
| DNS Belgium WHOIS and RDAP | not "to apply automated, electronic processes to DNS Belgium (or its systems)" | clearly excluded without permission |

**Publishing the server code.** The repository holds code and list URLs,
never list contents: the server downloads each list at runtime and keeps it
in memory. Redistribution clauses (OpenPhish, PhishStats, Web Risk "must not
be redistributed", IPQS) are about the data, so publishing the code does not
breach them. Points that do follow:

- Whoever runs a copy of the server is the user under each provider's terms,
  not Appmire. The README should say so and list the terms per source, and
  each source should be switchable by configuration, so that a self-hoster
  can turn off what they are not entitled to use.
- No list snapshot may go into the repository, not even as a test fixture.
  Tests should use synthetic host names.
- API keys stay out of the repository. Google's API terms say "Developer
  credentials may not be embedded in open source projects."
  <https://developers.google.com/terms>
- The preview API answers per-host verdicts to anyone holding the app key,
  which is in every copy of the app. For a provider whose terms forbid
  passing data on (Web Risk, OpenPhish), the public endpoint is a lookup
  service for third parties, not only a warning shown to the app's user.
  Rate limits on the endpoint keep this in proportion; a provider may still
  see it differently.

**GPL-3.0 and CC licences.** GPL obligations start when a work is conveyed;
the GNU FAQ: "The GPL does not require you to release your modified version,
or any part of it", and running a program on a server is not conveying it
(only the AGPL adds a network clause, and none of the lists here is AGPL).
Downloading a GPL list and querying it does not make the MIT server code a
derivative of the list, and "the output of a program is not, in general,
covered by the copyright on the code of the program", so a verdict is not
GPL material either. If a list file is ever shipped (in the repo or the
app), it must keep its GPL licence and notice; the MIT code next to it stays
MIT. CC BY and CC BY-NC require attribution when material is shared; CrUX
attribution belongs in the server README. The share-alike case does not
arise: CrUX is CC BY 4.0, not CC BY-SA as Tranco's attribution page states.
<https://www.gnu.org/licenses/gpl-faq.html#GPLRequireSourcePostedPublic>,
<https://www.gnu.org/licenses/gpl-faq.html#WhatCaseIsOutputGPL>,
<https://developer.chrome.com/docs/crux/methodology>

**Whom to ask.** Short e-mails, each stating: free app, no ads or purchases,
MIT source, run by Appmire CommV in Belgium, host names (or hash prefixes)
looked up per scan, expected volume.

- Whalebone (DNS4EU), contact@joindns4.eu: may a company's public-interest
  preview server keep querying the protective resolver at a few queries per
  scan, or is there a free tier of their commercial offering for this?
- Google (Safe Browsing): does a free, ad-free app published by a company
  fall under "non-commercial", and if not, is a separate agreement possible?
- Spamhaus: does the free Datafeed Query Key cover a free, non-revenue app
  run by a small company, for DBL lookups of web host names?
- abuse.ch: is this use "not-for-profit" under section 3.1, or does it need
  the paid subscription?
- Cisco Talos (PhishTank): may `online-valid.csv` be used in a free public
  service, and are the Cisco General Terms really the applicable licence?
- urlscan.io: written permission to search existing public scans by host
  name, for measurement only, or for production.
- DNS Belgium: permission for automated WHOIS lookups of the registration
  date, about one per new `.be` domain, cached for days; or an RDAP endpoint
  for `.be`.
- Cloudflare: whether 1.1.1.2 may be queried by a company's server for this
  purpose (the published wording does not forbid it).

## Comparison table

Sizes and counts are as downloaded on 12 November 2026.

| Source | Type | Access | Licence and commercial use | Sent to third party | Size, update | Coverage and overlap | Effort | Verdict |
|---|---|---|---|---|---|---|---|---|
| Quad9 (in use) | DNS | keyless | "completely free for everyone"; no terms of service published | host name | NXDOMAIN | weakest of the three on fresh phishing | done | keep |
| Cloudflare 1.1.1.2 (in use) | DNS | keyless | governed by the privacy policy; no usage restriction published | host name | `0.0.0.0` | 48/65 OpenPhish | done | keep; ambiguous, ask if convenient |
| DNS4EU protective (in use) | DNS | keyless | "strictly for their use in a personal capacity"; "not eligible for enterprises" | host name | block-page IP | strongest of the three | done | clearly excluded: ask Whalebone or remove |
| Phishing.Database (in use) | list | keyless | MIT | nothing | 392,164 hosts, 11 MB; **frozen since 2 Oct 2026** | 485 `.be` hosts, the most of any list; decaying | done | keep for now, add staleness alarm, re-check monthly |
| CERT Polska warning list | list | keyless | any purpose incl. commercial, no attribution needed | nothing | 124,551 domains, 2.6 MB; every 5 min | Poland-targeted; 22 `.be`; 0.1% overlap with Phishing.Database; resolvers already block most live entries | low (same code path) | adopt |
| PhishDestroy destroylist | list | keyless | MIT | nothing | 238,144 domains, 5 MB; hourly | own detection; under 5% overlap with other lists; 57 `.be` | low | adopt after false-positive test |
| Hagezi TIF medium | list | keyless | GPL-3.0; upstream feeds have own terms | nothing | 373,421 domains, 6.9 MB; daily | includes CERT.pl partly (55%); 12k `.fr`, 6k `.de`, 70 `.be` | low | test |
| Hagezi TIF full | list | keyless | GPL-3.0 | nothing | 1,482,194 domains, 27 MB; daily | 312 `.be`; higher false-positive risk | low, memory cost | test, medium first |
| Phishing Army | list | keyless | project's own work unrestricted; "every user must respect the terms of the independent sources", which include OpenPhish | nothing | 143,103 domains, 3 MB | 87% of it is CERT.pl; covers 96% of OpenPhish feed, 95% of new PhishTank | low | skip: inherits OpenPhish's exclusion of organisations |
| OpenPhish community feed | list | keyless | "solely for your personal use"; excludes "detection ... customer protection, or other business functions of any organization" | nothing | 300 URLs, 17 kB; every 12 h | fresh, but resolvers block all live hosts already | low | skip (clearly excluded) |
| PhishTank `online-valid.csv` | list | keyless download works; key for automation | Cisco General Terms: use "for Your direct benefit", no providing functionality "to any third party" | nothing | 46,301 rows, 19,164 hosts, 8.9 MB; hourly | about 110 new per day; US and Polish brands; 8 `.be` | low | measurement only; leaning excluded for production, ask Cisco Talos |
| PhishStats | list/API | 50 requests/day keyless, 150 with free key | "lawful security research, threat intelligence, and related purposes"; no redistribution of raw feeds | query | 90-minute updates | unknown | medium | skip (ambiguous, quota too small) |
| phishunt.io | list | keyless | terms page not read, **unverified** | nothing | 944 URLs; hourly | derived from GSB, OpenPhish, PhishTank, urlscan | low | measurement only |
| curben phishing-filter | list | keyless | derived from PhishTank and OpenPhish | nothing | 19,310 domains | 87% PhishTank | low | skip |
| abuse.ch URLhaus, ThreatFox | list/API | free Auth-Key, account required | "for not-for-profit purposes"; companies "with commercial or for-profit needs may require a paid subscription" | nothing (dumps) | generated every 5 min | malware delivery and C2, little phishing | medium | skip; ambiguous, ask abuse.ch if ever needed |
| blocklistproject | list | keyless | Unlicense | nothing | **archived 27 Oct 2026** | aggregate of other lists | - | skip (dead) |
| StevenBlack hosts | list | keyless | MIT, sources mixed incl. NC | nothing | 78,215 entries; updated 8 Nov 2026 | adware and malware, little phishing | low | skip |
| OISD big | list | keyless | no licence stated | nothing | 227,769 lines, 4.5 MB | ad-blocking first; phishing secondary | low | skip |
| uBlock Origin badware list | list | keyless | GPL-3.0 | nothing | 7,057 lines | filter syntax, not plain hosts; already inside Hagezi TIF | medium | skip (get it through TIF) |
| Spamhaus DBL | DNS | public mirrors, or free Datafeed Query Key | "non-commercial use by small and medium sized organisations"; no queries from "large shared hosting environments" | host name | - | strong on fresh domains | low | ambiguous: ask Spamhaus about the free query key |
| SURBL | DNS | public | free for organisations with "fewer than 1,000 users"; software developers above that "MAY NOT" use it | host name | - | spam-advertised domains | low | skip: allowed only below 1,000 app users |
| CCB / BAPS list | list | not public | given to ISPs and partners only | - | - | the Belgian list; fed by suspicious@safeonweb.be | - | ask the CCB |
| Hagezi NRD lists | list | keyless | GPL-3.0; base data from Stamus Labs | nothing | 3.0 M domains for 7 days; daily, may lag | gTLD-heavy; ccTLD coverage unknown | high (memory) | skip; use RDAP per host instead |
| Control D free, malware (`76.76.2.1`) | DNS | keyless | general terms list "using Control D in a datacenter environment" as a termination ground | host name | answers `0.0.0.0` | blocked 65/65 OpenPhish, 3/30 Phishing.Database; no gain over current three | low | skip (leaning excluded, no gain) |
| AdGuard DNS default (`94.140.14.14`) | DNS | keyless | EULA forbids "automated agents or inject scripts" generating automated requests, and publishing benchmarks | host name | answers `94.140.14.33` | not published (EULA) | low | skip (excluded) |
| CIRA Canadian Shield protected (`149.112.121.20`) | DNS | keyless | for individuals and families in Canada (secondary source); terms page 403, **unverified** | host name | block-page IPs plus EDE 17; 120-150 ms from Europe | 28/30 Phishing.Database, the best of any resolver | low | skip (leaning excluded) |
| OpenDNS (`208.67.222.222`) | DNS | keyless | no current terms for the free service found; archived terms bar use "for the benefit of any third parties", **unverified** | host name | answers `146.112.61.108` | 52/65 OpenPhish, 6/17 CERT.pl; Cisco Talos data | low | skip (leaning excluded, no gain) |
| CleanBrowsing security (`185.228.168.9`) | DNS | keyless | free tier "for parents, not organizations"; no automated queries; no publishing benchmarks | host name | NXDOMAIN | not published (terms) | low | skip (clearly excluded) |
| UltraDNS threat protection (`156.154.70.2`) | DNS | keyless | not read, **unverified** | host name | answers `156.154.112.16` | weak: 13/65, 14/17, 6/30 | low | skip |
| Comodo Secure DNS (`8.26.56.26`) | DNS | keyless | - | host name | 40% of queries timed out | no block signal seen | - | skip |
| Yandex safe (`77.88.8.88`) | DNS | keyless | Russian operator | host name | no block seen in 112 listed hosts | none | - | skip |
| Mullvad DNS | DNS | - | - | - | **public service shut down 2 Nov 2026**; never offered port 53 | - | - | skip (dead) |
| dns0.eu | DNS | - | - | - | **shut down October 2025** | - | - | skip (dead) |
| NextDNS | DNS | account | free tier with monthly query cap, **unverified** | host name tied to an account | - | configurable feeds | medium | skip (not anonymous) |
| Google Safe Browsing v5 | API | free key | "non-commercial use only", commercial meaning "for sale or revenue-generating purposes"; attribution and notice required | 4-byte hash prefixes, or nothing in local-list mode | - | best general phishing coverage | medium | ask Google; adopt local-list mode if allowed |
| Google Web Risk | API | Google Cloud billing account | paid enterprise product; "information returned by the Web Risk must not be redistributed" | Lookup: full URL. Update: hash prefixes | Lookup free to 100,000 calls/month (pricing **unverified**, from localized pages) | same data as Safe Browsing; includes CCB submissions | medium to high | fallback if Google refuses Safe Browsing |
| urlscan.io | API | free key | "provided only for your own personal use"; commercial use "requires express written permission" | search: host name. Scan: full URL, public by default | free plan 1,000 searches/day | verdicts on already-scanned hosts only | medium | skip, also for measurement, unless urlscan agrees in writing |
| VirusTotal public API | API | free key | "must not be used in commercial products or services" (not defined) | URL | 500/day, 4/min | - | - | skip (quota; wording ambiguous) |
| Cloudflare URL Scanner | API | free account token | terms not confirmed, **unverified** | full URL, public by default | - | has phishing verdict field | medium | skip (privacy) |
| AlienVault / LevelBlue OTX | API | free key | terms not readable, **unverified** | host name | - | community pulses, noisy | medium | skip |
| IPQS malicious URL scanner | API | free key | free access is "evaluation, testing, trial"; no republishing "API responses ... to any third-party" | full URL or domain | "1,000 free lookups" | phishing flag, risk score, domain age | low | skip (excluded for production) |
| CheckPhish, Netcraft, Microsoft SmartScreen | API | - | no usable free commercial API found, **unverified** | - | - | - | - | skip |
| MISP default feeds | lists | keyless | per feed | nothing | - | catalogue only; phishing entries are PhishTank, OpenPhish, CERT.pl, Phishing.Database, phishunt, PhishStats, Threatview | - | no new source |
| Domain age via RDAP | signal | keyless | per registry; DNS Belgium forbids "automated, electronic processes"; `.eu` discloses no dates | host name's registrable domain to the registry | one HTTPS call, cacheable for days | independent of reporting | medium | adopt as caution for RDAP TLDs; `.be` only with DNS Belgium's permission |
| Certificate age via crt.sh | signal | keyless | - | registrable domain | 11 s for one query in testing | proxy for site age | medium | skip; too slow for the request path |
| Tranco top 1M | signal | keyless | no licence for the combined list; includes Cloudflare Radar (CC BY-NC 4.0) | nothing | daily zip | popularity, allow signal | low | skip; use CrUX |
| CrUX top origins | signal | keyless (BigQuery, or a community mirror on GitHub) | CC BY 4.0 (Google), attribution only | nothing | 8.8 MB gz; monthly | popularity by real Chrome usage | low | adopt as allow signal |
| Hagezi URL shortener, DynDNS, badware hoster lists | signal | keyless | GPL-3.0 | nothing | 9,784 / 1,519 / 1,099 entries | context, not a verdict | low | adopt as caution context |

## Notes per category

### 1. Downloadable lists

**Phishing.Database.** MIT. Last commit to `phishing-domains-ACTIVE.txt`:
2026-10-02T15:30:28Z ("Update Feeds"). The `phishing-domains-NEW-today.txt`
file holds three lines. Issues are still opened daily, so the project is not
abandoned, but the automation is not running. The server keeps loading the
same file with a `304`, so nothing in the logs shows this. Whatever else is
decided, the list loader should log and expose the age of each list (for
example the `Last-Modified` header or a "newest entry" date) and `/healthz`
should go yellow when a list is older than a few days.
<https://github.com/Phishing-Database/Phishing.Database>

**CERT Polska warning list.** Data usage policy: "The Warning List may be used
by any user for any purpose, including commercial purposes", attribution not
required, no implication of endorsement by NASK or CERT Polska. Entries stay
for six months. Plain list at `https://hole.cert.pl/domains/v2/domains.txt`
(the v1 paths were retired in January 2025). The list is built from reports by
Polish users and Polish operators, so it is strongest on Polish brands, but
parcel, marketplace and bank kits are reused across countries: it holds 1,238
`.eu` and 591 `.de` domains and a handful with `kbc`, `easypark` or `4411` in
the name. <https://cert.pl/en/warning-list/>

**PhishDestroy destroylist.** MIT (confirmed through the GitHub API). The
README describes own detection through "30+ proprietary parsers" watching ads,
search results, social media, CT logs and typosquats, plus a community list
aggregated from other sources. Several variants: `list.txt` (primary, 238,144
lines), `dns/active_domains.txt` (resolving only, daily), and
content-verified lists. The repository tags lean towards crypto scams, so its
value for Belgian banking phishing is unproven, and the claim of own detection
is the project's own. An allowlist and an appeals form exist. Start with the
DNS-verified active list. <https://github.com/phishdestroy/destroylist>

**Hagezi TIF.** "The Lists are published under the GNU General Public License
v3.0", with the note that inputs have their own terms. GPL on a data file
that the server downloads and holds in memory does not reach the app or the
server code, since nothing is distributed. Sources named in `sources.md`
include DNSBunker, PhishDestroy, CERT.pl, Phishing-Database, Validin,
MetaMask, the uBlock Origin badware list, KADhosts and a Turkish government
list; OpenPhish, PhishTank, URLhaus and ThreatFox are not listed. Measured,
TIF full contains only 12% of Phishing.Database and 55% of CERT.pl, so it is
filtered, not a superset. GitHub and jsDelivr publish once a day at 11:00
UTC. <https://github.com/hagezi/dns-blocklists>,
<https://github.com/hagezi/dns-blocklists/blob/main/sources.md>

**abuse.ch (URLhaus, ThreatFox).** Every download now needs an Auth-Key in
the URL; `https://urlhaus.abuse.ch/downloads/hostfile/`,
`.../downloads/text_online/` and `https://threatfox.abuse.ch/downloads/hostfile/`
return `410 Gone`. Terms of use, section 3.1: "Authenticated Users may access
the Platforms for not-for-profit purposes"; section 3.2 caps volume at what is
"reasonably expected for non-commercial or non-profit purposes"; section 4.1:
use "by companies, networks, or individuals with commercial or for-profit
needs may require a paid subscription". None of these terms is defined.
Appmire is a for-profit company, but this particular use earns nothing, so
it is ambiguous; "may require" leaves abuse.ch the decision. Only Feodo
Tracker, SSL Blacklist and YARAify are CC0 "for both commercial and
non-commercial purposes", and those are botnet and certificate data of no
use here. The content is malware distribution and C2, which a QR scanner
rarely meets, so asking is low priority.
<https://abuse.ch/terms-of-use/>, <https://urlhaus.abuse.ch/api/>,
<https://threatfox.abuse.ch/export/>

**OpenPhish community feed.** Still published (300 URLs, every 12 hours, now
on GitHub). The terms do not turn on price: "The Services are provided solely
for your personal use"; research is allowed only if it "does not support your
organization's business operations"; and "You agree not to use any part of
the Services for any commercial purposes including, but not limited to,
security operations, threat intelligence, detection, enrichment, product
development, automation, customer protection, or other business functions
of any organization" without written consent. A company protecting the users
of its app is exactly that. Clearly excluded, also for measurement by
Appmire. <https://openphish.com/phishing_feeds.html>, <https://openphish.com/terms.html>

**PhishTank.** Alive: `online-valid.csv` downloads without a key (46,301
rows, newest entry from the same morning, 750 to 1,450 verified submissions a
month in 2026). Without a key "you will be limited to a few downloads per
day"; whether new registrations are open was not checked. The "Terms of Use"
link goes to the Cisco General Terms (version 6.0, last modified 10 September
2025), a generic licence for Cisco products that does not mention PhishTank.
Read literally: use is granted "for Your direct benefit", and you may not
"transfer, sell, sublicense, monetize, or provide the functionality of any
Software, Cloud Services, Subscription Offers, or Services to any third
party, except as authorized by Cisco". Warning app users from PhishTank data
is providing its function to third parties. Whether the General Terms are
really meant to govern a free community dataset is unclear. Leaning
excluded for production; internal measurement is "direct benefit". Ask
Cisco Talos. Targets are mostly "Other", Allegro and US brands.
<https://phishtank.org/developer_info.php>,
<https://www.cisco.com/c/en/us/about/legal/cloud-and-software/end_user_license_agreement.html>

**Phishing Army.** Aggregates Cisco Talos, PhishTank,
OpenPhish, CERT Polska, phishunt, urlscan.io, PhishStats, StalkPhish,
URLAbuse and AntiPhish.org. It calls itself "a non-commercial community
project created primarily for personal and individual protection", and
places no restriction of its own on use "by individuals, organizations or
commercial services", but "every user must respect the terms of the
independent sources behind them" and "Phishing Army cannot grant rights over
third-party data". OpenPhish's terms exclude organisations, so the
aggregate is not usable by a company even for a free app. 87% of it is the
CERT.pl list, which can be taken directly.
<https://phishing.army/license/>, <https://phishing.army/sources/>

**PhishStats.** Alive. Anonymous API use is capped at 50 requests a day per
IP, 150 with a free key. The licence grant (section 10) is "to access and use
the Service for lawful security research, threat intelligence, and related
purposes", which does not mention companies or price either way. Section 5
forbids sharing, reselling or redistributing "raw PhishStats data feeds"
without permission and bulk downloads "beyond your tier's quotas".
Ambiguous, and the quota is far too small for production.
<https://phishstats.info/>, <https://phishstats.info/terms>

**URLAbuse.** The public text file answers 403: "This file download is
deprecated. Please use the API." Registration required.

**blocklistproject.** Archived by the owner on 27 October 2026, read-only.
<https://github.com/blocklistproject/Lists>

**StevenBlack, OISD, AdGuard and uBlock lists.** Ad and tracker lists first.
StevenBlack is MIT but mixes sources under CC BY-NC-SA. OISD states no
licence. The uBlock badware list is GPL-3.0 and in filter syntax; it reaches
us through Hagezi TIF already. None adds phishing coverage worth the false
positives. <https://github.com/StevenBlack/hosts>, <https://oisd.nl/>,
<https://github.com/uBlockOrigin/uAssets>

**Spamhaus DBL.** Section 1.1.1: "The DNSBL Public Mirror is provided free
of charge for non-commercial use by small and medium sized organisations";
1.1.2 caps volume at what is "reasonably expected in circumstances of
non-commercial use". Section 2 sends to the paid Datafeed service
"companies, organizations, individuals and networks with email traffic
likely to breach or exceed the fair use principles" and "ISPs or commercial
spam filter services". "Non-commercial" is not defined, the policy is
written for mail filtering, and Appmire is a small organisation, so a free
app is plausibly inside. Separately, queries must come from "a recursive
resolver run on your own network or from a public resolver which supports
ECS", and "Queries originating from large shared hosting environments are
not accepted"; the stated route for that case is "a free Datafeed Query
Key". Ambiguous: ask Spamhaus whether the free key covers this use.
<https://www.spamhaus.org/blocklists/dnsbl-fair-use-policy/>

**SURBL.** Free use is for "individual users, small charitable or non-profit
organizations, small businesses or any other organizations that have fewer
than 1,000 users or that scan fewer than 250,000 messages per day", and
"does not include embedding our data in any way into products or services
for which a fee is charged". SecureQR charges no fee, so the second clause
does not bite. The first does: "Any end-user organization, including
software developers ... of 1,000 or more users MAY NOT use the SURBL free
queuery service (FQS)" (sic), and "Any product or service which makes use of
our intelligence must have a valid SDS usage agreement". Allowed only until
the app has 1,000 users, and the last sentence arguably requires an
agreement for any product. Skip. <https://surbl.org/usage-policy/>

**Belgium: CCB, Safeonweb, BAPS.** The Belgian Anti-Phishing Shield list is
built from messages sent to suspicious@safeonweb.be and from trusted
partners (FSMA, FPS Economy, the Federal Judicial Police through PhishNemo),
and is passed to the participating ISPs (Belnet, Proximus, Telenet, Orange),
whose resolvers redirect to a warning page. No public download, feed or
resolver was found. CCB press material says suspicious URLs are also
forwarded to Google Safe Browsing and Microsoft SmartScreen, which makes
Safe Browsing (or Web Risk) the indirect route to this data. Two things
follow:

- The server runs on a rented host, not behind a Belgian ISP resolver, so
  it gets no BAPS protection today.
- Asking the CCB for partner access (or for a resolver address that applies
  the list) is worth an e-mail. Appmire can also offer something in return:
  QR-borne phishing seen by the app.

The FSMA publishes its list of fraudulent trading sites as web pages, not as
a file; it could be scraped but the terms were not checked.
<https://ccb.belgium.be/news/strengthened-collaboration-federal-judicial-police-combat-phishing>,
<https://ccb.belgium.be/news/key-figures-2025>,
<https://www.fsma.be/en/warnings>

**Other national CERT lists.** No other EU CERT list comparable to CERT
Polska's was found in the time available. This is **unverified**, not a
finding that none exists. Several CERTs contribute to DNS4EU, which is
already in use.

**Newly registered domains.** Hagezi publishes NRD lists (GPL-3.0, base data
from Stamus Labs, which "doesn't promise daily updates"): 2.96 million
domains for the last seven days, 12 million for 35 days. That is far too
much memory for a signal that RDAP gives per host on demand, and ccTLD
coverage (`.be`) is not stated. Commercial NRD feeds (WhoXY and others) are
paid. <https://github.com/hagezi/nrd>

**Certificate Transparency feeds.** Following CT logs (certstream or a
self-hosted equivalent) finds look-alike domains before they are used, but it
is a detection project of its own: a permanent stream, keyword rules for
Belgian brands, and manual review. PhishDestroy says it already does this.
Not something to bolt onto a preview server.

**DGA lists.** Hagezi's DGA lists (633,261 domains for seven days) are
entropy-filtered NRDs. DGA domains are botnet C2, not something printed on a
QR sticker. Skip.

### 2. Protective DNS resolvers

Test of 12 November 2026, run from the development machine (not the
production server): 70 hosts
from the OpenPhish feed, 50 from CERT Polska and 50 from Phishing.Database,
picked at random, plus eight benign Belgian sites. Each host was asked once
at every resolver. Only hosts that still resolved at Google DNS count.

| Resolver | Block signal observed | OpenPhish (65 live) | CERT.pl (17 live) | Phishing.Database (30 live) |
|---|---|---|---|---|
| Quad9 `9.9.9.9` | NXDOMAIN, EDE 17 "Filtered" | 12 | 16 | 5 |
| Cloudflare `1.1.1.2` | `0.0.0.0`, EDE 16 "Censored" | 48 | 17 | 19 |
| DNS4EU `86.54.11.1` | `51.15.69.11`, no EDE | 61 | 16 | 24 |
| **Current three together** | | **65** | **17** | **28** |
| Control D `76.76.2.1` (open: `76.76.2.0`) | `0.0.0.0`, no EDE | 65 | 17 | 3 |
| AdGuard `94.140.14.14` (open: `94.140.14.140`) | `94.140.14.33` | not published | | |
| CIRA `149.112.121.20` (open: `149.112.121.10`) | `127.0.0.1`, or `75.2.110.227`/`99.83.178.7` (phishing), `75.2.78.236`/`99.83.179.4` (malware); EDE 17 with text | 54 | 17 | 28 |
| OpenDNS `208.67.222.222` (open: `208.67.222.2`) | `146.112.61.108` | 52 | 6 | 3 |
| CleanBrowsing `185.228.168.9` | NXDOMAIN, no EDE | not published | | |
| UltraDNS `156.154.70.2` (open: `156.154.70.1`) | `156.154.112.16`, `156.154.113.16` | 13 | 14 | 6 |
| Yandex `77.88.8.88` | none seen | 0 | 0 | 0 |
| Comodo `8.26.56.26` | none seen; 73 of 178 queries timed out | - | - | - |

No benign host was blocked anywhere. The other resolvers added 0 hosts on the
OpenPhish and CERT.pl samples and 2 on the Phishing.Database sample (both
from CIRA). The sample is small and comes from public feeds that resolvers
ingest, so it shows overlap, not real-world detection; section 5 describes
the proper measurement. Response times were 27 to 39 ms for all but CIRA
(120 to 150 ms) and Yandex (80 to 90 ms). Figures for AdGuard and
CleanBrowsing are left out: their terms forbid publishing "benchmark tests
or analyses" without written consent, and this document is public.

Things the test shows beyond the numbers:

- Quad9 and Cloudflare send Extended DNS Error codes (17 and 16). Reading
  the EDE would make the check robust without the second, unfiltered query,
  but Node's `dns` module does not expose it, so the two-query approach
  stays.
- Quad9, the best-known of the three, is the weakest on fresh phishing
  hosts. DNS4EU carries most of the load.
- AdGuard's public page says the default server blocks "ads and trackers"
  only, yet in the test it did block phishing hosts. An ad-blocking resolver
  also raises the false-positive risk (ad and tracker redirect hosts in a
  chain would be flagged as malicious).
- CIRA distinguishes phishing from malware in the answer, which no other
  resolver does.

Terms, per resolver:

- **Quad9.** No terms of service are published; the site says "No sign-up is
  required ... and there is no contract", and the FAQ "Quad9 is completely
  free for everyone", asking large organisations to make contact before
  sending large-scale traffic. Nothing excludes a company's server. Fed by
  "around twenty" threat-intelligence sources, not named. Allowed as far as
  published. <https://quad9.net/>, <https://www.quad9.net/support/faq/>,
  <https://quad9.net/service/threat-blocking/>
- **Cloudflare 1.1.1.1 for Families.** Blocks "malware, phishing"; returns
  `0.0.0.0`. "The 1.1.1.1 public DNS resolver is governed by our Privacy
  Policy"; Families "is designed to help individuals protect their home
  networks", which describes the audience but is not written as a
  restriction. The website terms list the resolver among the online services
  and forbid exceeding limits. Ambiguous, leaning allowed.
  <https://developers.cloudflare.com/1.1.1.1/setup/>,
  <https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/>,
  <https://www.cloudflare.com/website-terms/>
- **DNS4EU (in use).** The terms of use (last updated 1 June 2025, contact
  Whalebone, s.r.o.) are explicit. Section 1: the service "is made available
  to individuals free of charge, strictly for their use in a personal
  capacity, and is designed for manual configuration." Section 2: "The
  Service is not eligible for enterprises or connectivity providers." The
  public page adds that it "is not intended for business networks". A
  company's server querying it for every scan is outside both, and that
  SecureQR is free does not change it. Clearly excluded. The rate limit
  (1,000 queries per second per IP, from a CZ.NIC slide) remains
  **unverified**; the terms only forbid exceeding "any usage limits".
  Options: ask Whalebone (contact@joindns4.eu) for permission, use their
  commercial product, or drop DNS4EU. Dropping it hurts: on the test sample
  16 of 65 live OpenPhish hosts and 7 of 30 live Phishing.Database hosts
  were blocked by DNS4EU alone (CERT.pl: 0 of 17).
  <https://legal-documents-dns4eu.s3.fr-par.scw.cloud/DNS4EU-Public-Resolver-Terms-of-Use.pdf>,
  <https://www.joindns4.eu/for-public>
- **Control D free.** Resolver addresses and "filters are rebuilt ... every
  30 minutes" confirmed. The free-DNS page has no terms of its own and sends
  business users to an organisation account. The general terms let Control D
  "impose usage or service limits ... at our sole discretion", forbid
  reselling or distributing the service, and list "using Control D in a
  datacenter environment" among grounds for termination (possibly meant for
  paid accounts). A server in a data centre is exactly that. Leaning
  excluded. <https://docs.controld.com/docs/free-dns>, <https://controld.com/terms>
- **AdGuard DNS.** The EULA grants "a limited license to connect to and use
  AdGuard DNS"; section 4 forbids "automated agents or inject scripts into
  AdGuard DNS products and services" that generate automated requests, and
  running or disclosing "benchmark tests or analyses" without written
  consent. A server issuing lookups for every scan is automated requests.
  Excluded. <https://adguard-dns.io/eula.html>
- **CIRA Canadian Shield.** The terms page returned 403. A 2020 law-firm
  summary says the terms permit use by individuals and families residing in
  Canada, with a paid DNS Firewall for organisations. **Unverified** from the
  primary source, but leaning excluded on both counts.
- **OpenDNS.** The free resolvers still answer and block. No current terms
  for the free service were found: the terms page points to the Cisco General
  Terms (use "for Your direct benefit", no providing functionality "to any
  third party") and to archived enterprise terms that forbid using the
  service "for the benefit of any third parties". Leaning excluded,
  **unverified** which terms apply.
- **CleanBrowsing.** The free tier is "Free DNS filtering for parents, not
  organizations" and throttled. Terms section 2.2 (d) forbids scripts that
  generate automated queries, and (f) forbids to "perform or publish any
  benchmark tests or analyses relating to the Cloud Services without
  CleanBrowsing's written consent". Clearly excluded.
  <https://cleanbrowsing.org/filters/>, <https://cleanbrowsing.org/terms/>
- **Mullvad.** Announced on 3 September 2026 that its public encrypted DNS
  would close on 2 November 2026 in favour of sponsoring Quad9; the help page
  carries the same date. It never accepted plain port-53 queries.
  <https://mullvad.net/en/help/dns-over-https-and-dns-over-tls>
- **dns0.eu.** Discontinued in October 2025; the operators pointed users to
  DNS4EU and NextDNS.
- **NextDNS.** Needs an account and a per-account endpoint, so lookups are
  tied to an identity. Not examined further.
- **Yandex, Comodo, UltraDNS.** No value measured; see table.

### 3. Keyed APIs

**Google Safe Browsing v5.** Technically the best fit: `hashes.search` sends
only a 4-byte hash prefix, a local-list mode sends nothing per lookup, and an
Oblivious HTTP gateway hides the client IP from Google. The terms: "The Safe
Browsing API is for non-commercial use only. If you need to use APIs to
detect malicious URLs for commercial purposes – meaning 'for sale or
revenue-generating purposes' – please refer to the Web Risk API", and "Unless
you have a separate agreement with Google, you may not use the Safe Browsing
API for commercial purposes." The definition is about money, not about who
the user is. SecureQR is not sold and generates no revenue, so on the
wording it falls inside non-commercial use. What cuts against it: the app is
published by a company and carries its name, and Google decides what
"revenue-generating" covers. Ambiguous, leaning allowed; worth a written
question to Google before building on it. Conditions if used: "attribution
and conspicuous notice that the reliability and accuracy of the service
cannot be guaranteed" before first use and with each warning, no Google
attribution on warnings from other sources, and the API key kept out of the
repository. <https://developers.google.com/safe-browsing/reference>,
<https://developers.google.com/safe-browsing/terms>

**Google Web Risk.** The paid counterpart, described as "a new enterprise
security product". "The information returned by the Web Risk must not be
redistributed", which matters for the public preview API (see "Free and open
source"). Two modes: the Lookup API (`uris.search`) sends the full URL to
Google; the Update API keeps a local database of hash prefixes
(`threatLists.computeDiff`) and confirms hits with `hashes.search`. Pricing
as found on localized copies of the pricing page (the English page did not
load, so treat as **unverified**): Lookup free up to 100,000 calls a month,
then $0.50 per 1,000; `computeDiff` free; `hashes.search` $50 per 1,000
calls. At the Lookup free tier and up to six hosts per scan, that is roughly
16,000 scans a month before paying, less the 30-minute cache. The
privacy-preserving mode is the expensive one, though `hashes.search` is only
called on a local prefix hit, which is rare for benign URLs. Needs a Google
Cloud project with billing. Because Chrome and other browsers built on Safe
Browsing use the same data, the lift for users is smaller than it looks: a
link that Safe Browsing knows would also be stopped by the phone's browser.
The value is in telling the user before they open it. Only needed if Google
refuses Safe Browsing. <https://cloud.google.com/web-risk/pricing>,
<https://docs.cloud.google.com/web-risk/docs/overview>

**urlscan.io.** Free plan, per day: 1,000 search requests, 5,000 public,
1,000 unlisted and 50 private scans, 10,000 result requests. Searching
existing scans by domain does not submit anything new, so a host-name query
(`domain:example.com`) is comparable in privacy to a DNS lookup, though tied
to an API key. The terms, however, say the site "is provided only for your
own personal use", "may not be used in connection with any commercial
endeavors except those that are specifically endorsed or approved by us",
and "Commercial use of any part of our service requires express written
permission"; commercial customers get separate terms. A company building and
measuring a public service is not personal use, so this is excluded even as
a measurement input unless urlscan agrees in writing.
<https://urlscan.io/pricing/>, <https://urlscan.io/terms/>

**VirusTotal.** "The Public API must not be used in commercial products or
services" and "must not be used in business workflows that do not
contribute new files", 500 requests a day. "Commercial product" is not
defined, so a free app may be outside the first sentence, but a company's
service is plausibly a business workflow, and the quota rules it out anyway.
<https://docs.virustotal.com/reference/public-vs-premium-api>

**Cloudflare URL Scanner and Radar.** The scanner needs an account token;
scans are public by default and the full URL is submitted. It does return a
malicious verdict and a phishing field; its terms were not checked
(**unverified**). Radar: "Data available via Radar API endpoints is made
available under the CC BY-NC 4.0 license." CC BY-NC defines NonCommercial as
"not primarily intended for or directed towards commercial advantage or
monetary compensation". A free app is not monetary compensation; the company
name on it is the only "commercial advantage" argument, and it is a weak one,
but it exists. <https://developers.cloudflare.com/radar/investigate/url-scanner/>,
<https://developers.cloudflare.com/radar/>,
<https://creativecommons.org/licenses/by-nc/4.0/legalcode.en>

**AlienVault OTX (now LevelBlue).** The API and terms pages did not render;
terms and limits **unverified**. Community pulses are noisy and would need
curation.

**IPQS.** Free sign-up advertises 1,000 lookups; the full URL or domain is
sent. The terms treat free access as "evaluation, testing, trial, or
proof-of-concept purposes (including any free or pilot access)" and forbid
to "Resell or republish IPQS data, IPQS API responses ... to any
third-party". Showing the verdict to app users is republishing a response.
Excluded for production.
<https://www.ipqualityscore.com/documentation/malicious-url-scanner-api/overview>,
<https://www.ipqualityscore.com/terms-of-service>

**CheckPhish, Netcraft, Microsoft.** The CheckPhish pricing page returned
403. No free Netcraft API for commercial use and no public SmartScreen
lookup API were found. All **unverified**.

**MISP default feeds.** The catalogue lists nothing for phishing beyond
sources already covered here (PhishTank, OpenPhish, CERT.pl,
Phishing.Database, phishunt, PhishStats, Threatview.io). It still points at
URLhaus download URLs that now need a key. <https://www.misp-project.org/feeds/>

### 4. Signals that are not lists

**Domain age through RDAP.** The IANA bootstrap file (published 28 October
2026) lists RDAP servers for 1,203 TLDs.

| TLD | RDAP in IANA bootstrap | Registration date returned | Fallback |
|---|---|---|---|
| `.com`, `.net`, `.org`, most new gTLDs (`.xyz`, `.top`, `.shop`, `.online`, `.site`, `.app`, `.dev`, `.icu`, `.cfd`, `.sbs`) | yes | yes | - |
| `.nl` | yes (`rdap.sidn.nl`) | yes | - |
| `.fr` | yes (`rdap.nic.fr`) | yes | - |
| `.be` | **no** | - | port-43 WHOIS at `whois.dns.be` returns `Registered: <date>` |
| `.eu` | **no** | - | port-43 WHOIS discloses no dates; web WHOIS only |
| `.de` | no (`rdap.denic.de` answers but is not in the bootstrap) | no, only "last changed" | none |
| `.vlaanderen`, `.brussels`, `.gent` | yes | not tested | - |
| `.uk`, `.pl`, `.cz`, `.fi`, `.no`, `.ch` | yes (`.ch` answers at `rdap.nic.ch`, not in bootstrap) | not tested | - |
| `.it`, `.lu`, `.at`, `.es`, `.io`, `.co`, `.me` | no | - | `.it` WHOIS shows `Created`; others not tested |

The README's statement that `.be` has no RDAP still holds. DNS Belgium
publishes RDAP terms and runs RDAP for `.vlaanderen` and `.brussels`, but no
`.be` endpoint is in the bootstrap file and the obvious host names do not
resolve. The `.be` WHOIS does give the date, but the terms (the same text
for RDAP and WHOIS) forbid "to apply automated, electronic processes to DNS
Belgium (or its systems)", and say that "any reproduction and/or
transmission of data for commercial purposes will always be considered" an
extraction of a substantial part of the database. DNS Belgium's own
documentation says WHOIS "is not suitable for websites or automated systems"
and caps it at 100 queries per hour per IP. A server looking up domains on
its own is an automated process, free app or not. Excluded without written
permission; DNS Belgium should be asked, and it would be a natural contact
for a Belgian security product anyway. The other registries' acceptable-use
policies (SIDN, AFNIC, the gTLD registries) were not read and are
**unverified**. <https://data.iana.org/rdap/dns.json>,
<https://www.dnsbelgium.be/en/rdap>,
<https://docs.dnsbelgium.be/be/general/whoisanddas.html>

How to use it: a domain registered less than about 30 days ago is a caution
reason ("This site is very new"), never a danger on its own. Cache per
registrable domain for days. Free-hosting subdomains (`*.vercel.app`,
`*.pages.dev`) carry the age of the platform, so the signal is blind there.

**Certificate age through crt.sh.** A single query for `bpost.be` took 11
seconds. Too slow and too unreliable for the request path. A newest-ever
certificate is also a weak signal: a free-hosting subdomain or a wildcard
hides it.

**Popularity lists.** A host in the top of a usage-based ranking is almost
never a phishing page of its own (it can still host one; free hosting and
shorteners must be excluded). Use it to suppress cautions and to weigh
single-source list hits, never to override a blocklist hit outright.
Tranco is the research standard and is published daily, but states no
licence for the combined list and blends in Cloudflare Radar data (CC BY-NC
4.0). CrUX is "licensed under a Creative Commons Attribution 4.0
International License" (Google's methodology page; Tranco's attribution
page says CC BY-SA, which is wrong), is based on real Chrome use, and comes
as rank buckets (top 1k, 10k, 100k, 1M); a community mirror publishes it as
a file (`zakird/crux-top-lists`, 8.8 MB compressed). Attribution goes in the
server README. CrUX has per-country data in BigQuery, which would give a
Belgian top list (not tested). <https://tranco-list.eu/>,
<https://developer.chrome.com/docs/crux/methodology>

**Shortener, dynamic-DNS and free-hosting lists.** Hagezi publishes URL
shortener (9,784 entries), DynDNS (1,519) and "badware hoster" (1,099)
lists, all small. A QR code that leads through a shortener to a page on a
free subdomain service that asks for card details is a much stronger case
than any of those facts alone; `verdict.ts` could combine them. The Public
Suffix List private section, already used through `tldts`, gives the "is
this a shared hosting suffix" answer for free.

**TLD risk.** Hagezi publishes a "most abused TLDs" list. A TLD is a weak signal and unfair to legitimate users of
cheap TLDs; use it at most as a tie-breaker together with domain age.

**ASN and hosting reputation.** No free, commercially usable feed with a
clear licence was found (**unverified**; not searched in depth). Phishing on
Cloudflare, Vercel and similar platforms makes the hosting network nearly
meaningless.

### What the lists look like for Belgium

Host names per list ending in `.be`, and containing a Belgian brand string
(crude: substring match, so `kbc` and `ing-` over-count).

| | Phishing.Database | CERT.pl | TIF medium | TIF full | destroylist | PhishTank |
|---|---|---|---|---|---|---|
| `.be` hosts | 485 | 22 | 70 | 312 | 57 | 8 |
| `itsme` | 15 | 1 | 2 | 14 | 2 | 1 |
| `bpost` | 44 | 0 | 7 | 15 | 0 | 2 |
| `kbc` | 45 | 14 | 17 | 55 | 15 | 1 |
| `argenta` | 10 | 0 | 1 | 8 | 3 | 1 |
| `easypark` | 0 | 11 | 43 | 66 | 0 | 0 |
| `parking` | 91 | 15 | 51 | 363 | 7 | 20 |

No open list has meaningful Belgian coverage. The frozen Phishing.Database
has the most, which is a reason not to drop it yet. Belgian phishing is in
BAPS and, through the CCB, in Google Safe Browsing.

### Overlap between lists

Share of the row list that is also in the column list (host or a parent
domain):

| | Phishing.Database | CERT.pl | TIF medium | TIF full | Phishing Army |
|---|---|---|---|---|---|
| Phishing.Database (392,164) | - | 0.0% | 3.5% | 11.7% | 0.3% |
| CERT.pl (124,551) | 0.1% | - | 55.1% | 55.2% | 99.8% |
| TIF medium (373,421) | 0.9% | 16.6% | - | 100% | 17.6% |
| destroylist (238,144) | 4% | 3% | 6% | 18% | 5% |
| PhishTank last 7 days (783 hosts) | 0% | 33% | 41% | 48% | 95% |
| OpenPhish feed (242 hosts) | 5.0% | 1.7% | 12.4% | 21.5% | 96.3% |

The open lists are close to disjoint, apart from the aggregators. Adding
CERT.pl, destroylist and TIF medium to the current list costs roughly 14 MB
of downloads and, as a rough guess, 100 to 150 MB of heap if each is held as
a JavaScript `Set` of strings (not measured). If memory matters, merge all
lists into one set, or store 64-bit hashes of host names in a typed array.

## Measuring detection rate

Nothing above says how many real scans a source would catch. Before
integrating anything beyond the cheap lists, measure the marginal lift over
the current four.

**Ground truth, malicious.** Fresh URLs, taken at the moment they first
appear:

- PhishTank `online-valid.csv`, polled hourly, new `phish_id`s only (about
  110 a day). Keyless; internal measurement is the "direct benefit" the Cisco
  terms allow, but confirm with Cisco Talos.
- phishunt.io `feed.txt` (hourly, about 900 active URLs). Terms not read
  (**unverified**); check before use.
- New entries in the CERT Polska list (diff every 5 minutes).
- urlscan.io search for recent scans with a malicious verdict would give a
  Belgian slice, but its terms limit the service to personal use; only with
  urlscan's written permission.
- Belgian samples collected by hand: smishing texts and QR stickers reported
  in the press and on Safeonweb's news pages, plus anything users report
  through the app. Small, but it is the slice that matters most. Keep it as
  a separate, labelled set.

The OpenPhish feed is the obvious fifth source, but its terms exclude use
for the business functions of any organisation, research included.

**Ground truth, benign.** Three sets, because false positives differ by
kind:

- Top sites: a random sample from CrUX top 100k.
- Belgian long tail: `.be` sites outside the top lists (municipalities,
  restaurants with QR menus, parking operators, payment providers,
  Payconiq and Bancontact landing pages).
- What QR codes really contain: shortener links, app-store links, Wi-Fi
  portals. Collect this set by hand.

**Procedure.**

1. A collector takes each new malicious URL when it first appears (`t0`) and
   stores URL, host, feed and timestamp.
2. At `t0`, `+1 h`, `+6 h`, `+24 h` and `+72 h` it records, for every
   current and candidate source, whether the host is flagged. At the same
   moments it records whether the site is still alive: the host resolves at
   an unfiltered resolver, the page answers 200, and it is not a parking or
   suspension page.
3. Run it for at least two weeks so weekday effects and feed outages
   average out.

**Numbers to report per source.**

- Detection rate on live URLs at each age. A source that only lists a site
  after it is dead is worth nothing, and a list that keeps dead hosts looks
  bigger than it is. Takedown decay is handled by only counting URLs that
  are alive at the moment of the check; phishing sites commonly live for
  hours, so the `t0` and `+1 h` columns are the ones that matter for a QR
  scanner.
- Marginal lift: share of live URLs flagged by the candidate and by none of
  the current four. This is the number to decide on.
- False-positive rate on each benign set, and the list of hosts, since one
  wrong block of `bpost.be` costs more than a hundred missed long-tail
  phish.
- Latency (median and 95th percentile) and failure rate.

**Avoiding circular results.** A source must not be scored on URLs from a
feed it ingests. Phishing Army "detects" 96% of OpenPhish because it
contains OpenPhish. Report results per ground-truth feed, and treat a
candidate's score on a feed it is known to consume as zero information. The
resolvers do not publish their feeds, so for them the Belgian hand-collected
set and the urlscan slice are the fairest test.

**Sample size.** With 1,000 live URLs the 95% confidence interval on a
detection rate is about plus or minus 3 points, enough to tell a 5-point
lift from noise. Sources are compared on the same URLs, so use a paired
test (McNemar) on the disagreements. The Belgian set will be far smaller;
report counts, not percentages.

**Order of work.** The collector and the comparison can be a script outside
the server, reusing `buildReputation` with each candidate as a `Provider`.
Lists and resolvers cost nothing to include. Web Risk Lookup fits within its
free tier for a two-week measurement.

## Open questions and unverified claims

- **DNS4EU.** The terms are clear (personal use, no enterprises); whether
  Whalebone would permit this use is the open question. The 1,000 queries
  per second figure comes from a conference slide.
- **Phishing.Database.** Why the updates stopped on 2 October 2026 and
  whether they will resume is unknown. No announcement was found.
- **PhishTank terms.** The linked licence is the generic Cisco General
  Terms, which do not mention PhishTank; whether they are meant to govern the
  data is unclear. Whether new API keys can still be registered was not
  tested.
- **Web Risk pricing.** Figures come from search results quoting the pricing
  page and its localized copies; the English page did not load. Confirm
  before budgeting.
- **Resolver terms.** Quad9 publishes no terms of service; Cloudflare only a
  privacy policy; OpenDNS's applicable terms for the free service are
  unclear; CIRA's page returned 403 (the residency rule comes from a 2020
  law-firm summary); Control D's datacenter clause may be meant for paid
  accounts only; UltraDNS was not read.
- **Feeds behind each resolver.** None publishes its list of suppliers. The
  overlap table is the only evidence.
- **OTX and Cloudflare URL Scanner:** terms not read. urlscan.io and IPQS
  terms were read and exclude this use without permission.
- **CheckPhish, Netcraft, Microsoft SmartScreen:** no primary source read.
- **Licences confirmed from the owner:** Cloudflare Radar CC BY-NC 4.0
  (Cloudflare's Radar docs), CrUX CC BY 4.0 (Google). Tranco's attribution
  page gives CrUX as CC BY-SA, which is wrong.
- **Other national CERT lists** (Netherlands, France, Luxembourg, Baltic
  states and others): not found, not ruled out.
- **CCB statement on forwarding URLs to Google Safe Browsing and Microsoft
  SmartScreen** comes from CCB press material surfaced by search; the exact
  page was not read in full.
- **`.be` WHOIS:** the terms forbid automated processes; whether DNS
  Belgium would allow one cached lookup per new domain is unknown until
  asked. Other registries' RDAP acceptable-use policies were not read.
- **PhishDestroy's own-detection claims and false-positive rate** are the
  project's description; not tested.
- **Memory figures** for holding the lists are estimates.
- **Resolver test.** One run, 112 live hosts, from the development
  machine, not from the production server. Results from the
  data centre may differ (anycast node, rate limits).
- **Hagezi NRD coverage of ccTLDs** and **CrUX per-country lists as a file**
  were not checked.
- **Commercial definitions.** abuse.ch, Spamhaus, PhishStats and
  VirusTotal do not define "commercial" or "not-for-profit". The judgments in
  "Free and open source: what changes" apply the wording as published; the
  providers may read it differently.
- **Web Risk "must not be redistributed"** and the public preview API: not
  tested against Google's view.
