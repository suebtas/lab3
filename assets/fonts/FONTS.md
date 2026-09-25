# Font provenance for startup_hr

Bundled fonts used by the Flutter Web app. All fonts are open-source and
bundled as Flutter assets (no runtime font loading), keeping the CSP strict.

## Roboto (Apache License 2.0)

- Source: Google Fonts specimen — <https://fonts.google.com/specimen/Roboto>
  (upstream: <https://github.com/google/fonts/tree/main/apache/roboto>)
- License file: `Apache-2.0.txt` in this directory.
- Family registered in `pubspec.yaml` as weight-normal family (400/700) with
  Roboto Medium used for selected states.

| File                | SHA256 (binary font file)                                      |
| ------------------- | -------------------------------------------------------------- |
| `Roboto-Regular.ttf`  | `dece7c71bbe61710787f0839c722c65e87355dd2eb4a823e6b5488121ff81e4b` |
| `Roboto-Medium.ttf`   | `4d984240cefb093a74300bcae4b5dbd49f700e0af501eaaa079c56aa64142d2f` |
| `Roboto-Bold.ttf`     | `35757eaa996b3359022f47f164a67ee9eac04971af24c5b8fbd4b89e844ff190` |

## Noto Sans Thai (SIL Open Font License 1.1)

- Source: Google Fonts specimen — <https://fonts.google.com/noto/specimen/Noto+Sans+Thai>
  (upstream: <https://github.com/notofonts/thai>)
- License file: `OFL.txt` in this directory.

| File                    | SHA256 (binary font file)                                      |
| ----------------------- | -------------------------------------------------------------- |
| `NotoSansThai-Regular.ttf` | `6c5e4ca047263ed8f07b174be2f7c396d245504ce0f77adc1d26b0978bc95426` |
| `NotoSansThai-Bold.ttf`    | `fd475b89dca5b9b2ad5f294944c6c82a1641c29b0a30bc1b771227250fb826a8` |

To recompute: `sha256sum assets/fonts/*.ttf`