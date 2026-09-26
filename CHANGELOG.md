# Changelog

Release notes for Zili. The version headings are what `Scripts/release-notes.sh`
reads and what the Release workflow writes into App Store Connect's "What's New"
— so a heading is `## <version>`, matching the tag exactly.

Write the entries to survive both renderings. The changelog is read as Markdown
here and as plain text on the store, where the field shows whatever it is given
verbatim: a line that only makes sense with its formatting will read badly in
one of the two places.

## 1.3

### NEW

- Drop a word or a sentence from your favorites by swiping it away, without
  opening it first. Favorites is the only set a swipe removes anything from.
- The practice pad now follows the system's "Only Draw with Apple Pencil"
  setting. With it on, the Pencil writes and a finger swipes between a word's
  characters, rather than the pad taking every stroke that lands on it.

### ACCESSIBILITY

- Chinese is spoken with the best voice on the device rather than the basic one
  installed by default. If you have downloaded a premium or enhanced Mandarin
  voice, Zili now uses it, and the difference is considerable.
- VoiceOver no longer reads a word's pinyin straight after its Hanzi. The
  characters have already been read aloud in Chinese, and hearing the same word
  again in an English voice said it twice and said it badly. A reading still
  speaks for itself wherever it stands alone, such as a flashcard that is
  holding the characters back.
- With VoiceOver, a Chinese word of more than one character now says what it is
  in your own language. The word itself is still read in Chinese, but the word
  "button" after it is not, and the hint that was left off to avoid that is
  back.
- Choosing which HSK standard or which sentences to browse no longer means
  opening a menu. In Practice, the choices sit in a row, on screen and one tap
  away.
- Flashcards honor "Prefer Cross-Fade Transitions". With Reduce Motion on, a
  card used to cut straight to its other side; it can now dissolve to it
  instead, for anyone who has asked for cross-fades in place of movement.

## 1.2

Tapping a word now selects the whole word. Zili segments Chinese the way a
reader does instead of guessing greedily from the character you touched, so 地方
comes up as one word rather than 地.

### NEW

- Ask Siri for a Chinese word, or search for one in Spotlight, and Zili answers
  with its reading and meaning. The same lookup is available as a Shortcuts
  action, so a word can be passed on to the rest of a shortcut. Type English,
  pinyin, or Hanzi in either script.
- Point at a word to peek it. On a Mac, on an iPad with a trackpad, or with a
  hovering Apple Pencil, resting on a word shows its reading and meaning without
  a tap.
- Squeeze an Apple Pencil Pro while practicing strokes to flash the character's
  shadow underneath your writing — the one control you can reach without lifting
  the pen. Settings can retune the squeeze to take back a stroke instead, or
  turn it off.
- Flip and grade flashcards from a hardware keyboard. Space turns the card over;
  the arrow keys judge it — right for correct, left for needs review, up to
  skip.
- A tip now points out that words in a sentence can be tapped, which was easy to
  miss.

### ACCESSIBILITY

- VoiceOver reads Hanzi in a Chinese voice everywhere the app shows it, rather
  than spelling characters out in an English one. In a sentence it now moves
  word by word instead of glyph by glyph, and reads a headword in Chinese while
  keeping its English meaning in your own voice.

### UNDER THE HOOD

- Opening a second window no longer waits on the dictionary and sentence
  corpora, or pays for a second copy of them.

## 1.1

### SORT YOUR FAVORITES

Quizzing your Favorites always dealt a random handful. Now the Recognition,
Drawing, and Listening quizzes each offer a Sort when Favorites is the set you
are quizzing: Random, Most Recent, or Oldest. Star a batch of new words and
drill exactly those, or go back to the stars that have waited longest. You still
get a fresh running order every time.

### OTHER CHANGES

- The Drawing quiz now keeps a word's characters together, in the order the word
  is written, instead of scattering them.
- Words you star while setting up a quiz now count toward the deck it deals.
- The end-of-quiz Favorites button no longer offers to add words you have
  already starred.

## 1.0

The first release. A Chinese dictionary, the HSK syllabus to work through,
sentence practice, and quizzes for recognition, stroke order, and listening.
