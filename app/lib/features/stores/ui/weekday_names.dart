import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// French name of [weekday] (0 = Monday ... 6 = Sunday).
String weekdayNameFr(AppLocalizations l, int weekday) => switch (weekday) {
      0 => l.weekday0,
      1 => l.weekday1,
      2 => l.weekday2,
      3 => l.weekday3,
      4 => l.weekday4,
      5 => l.weekday5,
      _ => l.weekday6,
    };
