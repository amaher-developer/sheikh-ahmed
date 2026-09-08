/// Adhan recordings played at prayer time. Streamed from aladhan.com's
/// public CDN (the same project behind the widely used prayer-times API)
/// rather than bundled, which keeps the APK small; every URL below was
/// verified reachable (HTTP 200, audio/mpeg) before shipping — same
/// approach as the radio stations and reciter servers.
class AdhanVoice {
  final String id;
  final String nameKey;
  final String url;

  /// Name of the same recording bundled as an Android raw resource, at
  /// `android/app/src/main/res/raw/[rawResource].mp3`.
  ///
  /// [url] covers in-app playback, but a *scheduled* notification can only
  /// reference a sound already on the device — it can't stream. Every voice
  /// is therefore bundled as well, so the adhan the user picked is the one
  /// that actually plays at prayer time with the app closed, which is the
  /// case that matters most. Previously only a1 was bundled and every
  /// scheduled adhan used it regardless of the setting.
  ///
  /// a1's file is named adhan_call for historical reasons — renaming it
  /// would mean re-pointing res/raw/keep.xml and the shrinker rule that
  /// depends on it, for no gain.
  final String rawResource;

  const AdhanVoice({
    required this.id,
    required this.nameKey,
    required this.url,
    required this.rawResource,
  });
}

const kAdhanVoices = <AdhanVoice>[
  AdhanVoice(
    id: 'a1',
    nameKey: 'adhan.voices.a1',
    url: 'https://cdn.aladhan.com/audio/adhans/a1.mp3',
    rawResource: 'adhan_call',
  ),
  AdhanVoice(
    id: 'a2',
    nameKey: 'adhan.voices.a2',
    url: 'https://cdn.aladhan.com/audio/adhans/a2.mp3',
    rawResource: 'adhan_a2',
  ),
  // Takes the slot, and the name, of the generic Egyptian adhan it
  // replaced: it is the Cairo adhan, recorded by Sheikh Mohamed Rifaat.
  //
  // Bundled rather than streamed: unlike the aladhan.com voices this
  // recording has no CDN to play from, so [url] points at the app's own
  // copy of the same file the notification uses. The historic 1930s
  // recording is 16kbps mono, which is why the whole thing fits in 0.4MB
  // — a fifth of the voice it replaced, despite being a full 3m24s adhan.
  AdhanVoice(
    id: 'a5',
    nameKey: 'adhan.voices.a5',
    url: 'asset:///assets/audio/adhan_a5.mp3',
    rawResource: 'adhan_a5',
  ),
  AdhanVoice(
    id: 'a4',
    nameKey: 'adhan.voices.a4',
    url: 'https://cdn.aladhan.com/audio/adhans/a4.mp3',
    rawResource: 'adhan_a4',
  ),
];

// Const list indexing isn't a constant expression in Dart, so this is
// `final` rather than `const` (same as kDefaultReciter).
//
// The Egyptian adhan, not simply the first entry: it is the one this
// app's audience expects to hear by default, and it is also the only
// bundled voice, so a fresh install plays the real adhan at the first
// prayer time without needing the network.
// firstWhere, not findAdhanVoice: that function falls back to *this*
// value, so defining it in terms of itself would recurse the moment 'a5'
// stopped existing. firstWhere throws loudly at startup instead, which is
// the right failure for a missing bundled voice.
final kDefaultAdhanVoice = kAdhanVoices.firstWhere((v) => v.id == 'a5');

AdhanVoice findAdhanVoice(String? id) {
  if (id == null) return kDefaultAdhanVoice;
  for (final voice in kAdhanVoices) {
    if (voice.id == id) return voice;
  }
  return kDefaultAdhanVoice;
}
