# Fonts

Inter 4.0 (SIL Open Font License 1.1, see `OFL.txt`).

- Source: https://github.com/rsms/inter/releases/tag/v4.0 (`Inter-4.0.zip`, `extras/ttf/Inter-{Regular,Medium,SemiBold,Bold}.ttf`)
- Version: 4.0 (2023-11-19)
- Modification: subset to Latin / Latin-1 / Latin Extended-A essentials, punctuation, U+202F, U+20AC, arrows and U+2212 with
  `pyftsubset` (fonttools), all OpenType layout features kept (including `tnum`). This reduces 1.64 MB to about 0.4 MB.
  Re-subset from the official release if more glyphs are needed.
