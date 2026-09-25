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

- Zili has a widget. It shows how many of your favorites are ready to review and
  the one that has waited longest, on the Home Screen, the Lock Screen, and the
  Mac's desktop. It counts for itself, so a word that comes due tomorrow appears
  there whether or not you have opened the app.
- A second widget brings a word a day from the HSK syllabus, with its reading
  and meaning. Tap it to open the word's full entry.
- Tapping the Due for Review widget opens straight into a review of your
  favorites, the ones you're closest to forgetting first. A Start Review control
  does the same from Control Center, the Lock Screen, or the Action button.
- The practice pad now follows the system's "Only Draw with Apple Pencil"
  setting. With it on, the Pencil writes and a finger swipes between a word's
  characters, rather than the pad taking every stroke that lands on it.
- Recognition quizzes can deal your favorites in the order you are closest to
  forgetting them. Choose "Due for Review" under Sort, and every word you judge
  sets when it comes back — tomorrow if you didn't know it, further out each
  time you do. The setup screen counts how many are due.

### ACCESSIBILITY

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
