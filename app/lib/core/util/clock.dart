import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now". Tests replace it to control time.
///
/// The device clock is only ever used for the refresh TTL and for display
/// hints (e.g. "ce prospectus est peut-être terminé"). It must NEVER decide
/// which flyer is current: that is always the server's answer.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
