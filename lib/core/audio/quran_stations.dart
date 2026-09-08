/// Live Quran radio stations. Every URL here was verified reachable
/// (HTTP 200, audio/mpeg) against the source before shipping — see
/// mp3quran.net's public `/api/v3/radios` listing, which is where the
/// backup.qurango.net URLs come from.
class QuranStation {
  final String nameKey;
  final String subtitleKey;
  final String url;

  const QuranStation({
    required this.nameKey,
    required this.subtitleKey,
    required this.url,
  });
}

const kQuranStations = <QuranStation>[
  QuranStation(
    nameKey: 'radio_screen.stations.general',
    subtitleKey: 'radio_screen.stations.general_sub',
    url: 'https://backup.qurango.net/radio/mix',
  ),
  // Second in the list on purpose: this is the Egyptian national Quran
  // station (98.2 FM in Egypt), the one most users here actually want.
  //
  // The stream id is attributed through radio-browser.info, where it is
  // listed five times under Egypt — "إذاعة القرآن الكريم من القاهرة" being
  // the top-voted — and one of those entries still carries a
  // listening-from-radio-garden parameter, which is what ties it to the
  // Radio Garden listing. It resolves to cleartext, which is why
  // network_security_config.xml carries a radiojar.com exception.
  QuranStation(
    nameKey: 'radio_screen.stations.cairo',
    subtitleKey: 'radio_screen.stations.cairo_sub',
    url: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
  ),
  QuranStation(
    nameKey: 'radio_screen.stations.makkah_imam',
    subtitleKey: 'radio_screen.stations.makkah_sub',
    url: 'https://backup.qurango.net/radio/saud_alshuraim',
  ),
  QuranStation(
    nameKey: 'radio_screen.stations.madinah_imam',
    subtitleKey: 'radio_screen.stations.madinah_sub',
    url: 'https://backup.qurango.net/radio/ali_alhuthaifi',
  ),
  // The Egyptian recitation stations. Both come from mp3quran's own
  // catalogue and were checked end to end before being added: 200
  // audio/mpeg with the *final* URL still on https, which is the part
  // that decides whether Android will play them at all.
  QuranStation(
    nameKey: 'radio_screen.stations.hussary',
    subtitleKey: 'radio_screen.stations.egypt_sub',
    url: 'https://backup.qurango.net/radio/mahmoud_khalil_alhussary',
  ),
  QuranStation(
    nameKey: 'radio_screen.stations.minshawi',
    subtitleKey: 'radio_screen.stations.egypt_sub',
    url: 'https://backup.qurango.net/radio/mohammed_siddiq_alminshawi',
  ),
  QuranStation(
    nameKey: 'radio_screen.stations.saudi_radio',
    subtitleKey: 'radio_screen.stations.saudi_radio_sub',
    url: 'https://stream.radiojar.com/0tpy1h0kxtzuv',
  ),
];
