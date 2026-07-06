# Zili 字里

[![Tests](https://github.com/HSK-Hanzi/iOS/actions/workflows/test.yml/badge.svg)](https://github.com/HSK-Hanzi/iOS/actions/workflows/test.yml)
[![Linters](https://github.com/HSK-Hanzi/iOS/actions/workflows/lint.yml/badge.svg)](https://github.com/HSK-Hanzi/iOS/actions/workflows/lint.yml)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg)](https://developer.apple.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Zili is an iOS and macOS SwiftUI app for learning to read and write Chinese,
organized around the HSK vocabulary levels.

## What It Is

Learning Chinese means drilling thousands of characters and words across several
skills at once — recognizing Hanzi, recalling pinyin and tones, understanding
meaning, hearing the spoken language, and writing the strokes in the correct
order. Most study tools cover only a slice of this.

Zili brings those skills together. You configure your HSK level and exactly how
you want to study, then work through interlocking modes:

- **Flashcards** drill in whichever direction and skill you choose —
  English↔Chinese, pinyin or Hanzi, pronunciation or strokes — with a physical
  card-flip reversal animation.
- **A dictionary** presents information-rich, well-typeset entries with tappable
  links; tap any Hanzi phrase anywhere in the app to see its pinyin and
  definition as a tooltip and jump to its entry.
- **Stroke-order practice** animates each character and, in test mode, marks
  your strokes red or green based on correct order and direction, with animated
  hints when you slip.
- **Practice** surfaces example sentences and conversations drawn from HSK
  material.
- **Quizzes** include a writing mode (draw the character you're shown) and a
  listening mode (transcribe a spoken sentence's pinyin).

## Requirements

Zili is written in Swift 6 and targets iOS 26 and macOS 26.

## Development

The Xcode project defines three targets:

- **Zili** — the application, buildable and runnable on iOS and macOS.
- **ZiliTests** — the unit test suite.
- **ZiliUITests** — the end-to-end UI test suite, built on
  [XCUITestKit](https://github.com/RISCfuture/XCUITestKit).

### Data submodules

The app's source data lives in two git submodules under `Data/`:

- **`Data/Open`** — openly licensed data, in a public repository.
- **`Data/Proprietary`** — licensed data, in a private repository.

Builds fall back to open-only data when `Data/Proprietary` is absent, so the app
still builds and the test suite still runs with just the public submodule
checked out. This is how CI runs, and why outside pull requests — which cannot
access private repositories or secrets — pass.

### Data resources

A **Copy Data Resources** build phase runs `Tools/generate_db.py`, which
converts the bundled property lists into prebuilt SQLite databases (dictionary,
frequency, strokes, and character stores). The app queries these lazily at
runtime rather than parsing large plists into memory.

### Crash reporting

[Sentry](https://sentry.io) is wired in for exception and crash reporting.

## Disclaimer

Zili is an independent study aid. It is not affiliated with, endorsed by, or
sponsored by HSK, Hanban, or any official Chinese-language testing body.
