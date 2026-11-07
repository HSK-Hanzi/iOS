# Changelog

Release notes for Zili. The version headings are what `Scripts/release-notes.sh`
reads and what the Release workflow writes into App Store Connect’s “What’s New”
— so a heading is `## <version>`, matching the tag exactly.

Write the entries to survive both renderings. The changelog is read as Markdown
here and as plain text on the store, where the field shows whatever it is given
verbatim: a line that only makes sense with its formatting will read badly in
one of the two places.

## 2.1

Practice and Quiz are now organized by skill, and new ways to practice fill
them out: say words and sentences back, pick a word out by ear, and read a
sentence aloud to be graded character by character.

### NEW

- Practice and Quiz lead with the same skills: Reading, Writing, Listening and
  Speaking. Each holds its ways to practice or be quizzed on characters and
  sentences. On the Mac, the Practice and Quiz menus follow the same skills.
- Speaking Characters practice: choose your words, then hear each one said and
  say it back. The card turns over to show its pinyin and meaning, and whether
  you said it right.
- Speaking Sentences, as practice and as a quiz: read a sentence aloud, and the
  card turns over to its pinyin and translation, marking any characters that
  weren’t heard said right. Tap a marked character to hear its word said.
  Practice says each sentence first for you to say back.
- Listening Characters, as practice and as a quiz: hear a word and pick it out
  from four that sound alike. In practice, a wrong pick is taken away and the
  word said again until you find it.
- Listening Sentences practice: hear a sentence and type it back, with another
  try at any you get wrong.
- On iPhone Duo, the writing pad moves off the fold when you bend the phone:
  below it in tabletop pose, with the character to write above, or beside it
  when you hold the phone like a book.
- Held like a book, iPhone Duo keeps the drawing round’s and the flashcards’
  buttons off the fold too, beside the character and its paper.
- Word grids on iPhone Duo’s inner display set an even number of columns, so the
  fold falls between two of them.
- Dictionary search results star the words you’ve favorited.

### FIXES

- Strokes you’ve drawn stay where you drew them when the writing pad changes
  size, as it does when you rotate, open or fold iPhone Duo, or resize Split
  View. They used to be redrawn at the wrong scale and graded again.
- In landscape on iPhone Duo’s outer display, the drawing round puts the
  character beside the paper, leaving room to write, and the pad’s Hint, Undo
  and Clear buttons fit.
- Flashcard text no longer runs under the bars along the side of iPhone Duo’s
  outer display.
- On the Mac, garbled text no longer appears above the progress bar while
  Mandarin speech recognition downloads.

## 2.0

Zili 2.0 requires iOS 27, iPadOS 27, macOS 27, or visionOS 27.

### NEW

- Zili has a widget. It shows how many of your favorites are ready to review and
  the one that has waited longest, on the Home Screen, the Lock Screen, and the
  Mac’s desktop.
- A second widget brings a word a day from the HSK syllabus, with its reading
  and meaning. Tap it to open the word’s full entry.
- Tapping the Due for Review widget opens straight into a review of your
  favorites, the ones you’re closest to forgetting first. A Start Review control
  does the same from Control Center, the Lock Screen, or the Action button.
- Drop a word or a sentence from your favorites by swiping it away, without
  opening it first. Favorites is the only set a swipe removes anything from.
- The practice pad now follows the system’s “Only Draw with Apple Pencil”
  setting. With it on, the Pencil writes and a finger swipes between a word’s
  characters.
- Recognition quizzes can deal your favorites in the order you are closest to
  forgetting them. Choose “Due for Review” under Sort: a word you miss comes back
  tomorrow, and one you know comes back later each time.
- A fourth quiz, Speaking, shows you a word and listens as you say it. It
  checks your tones as well as your syllables: a word that sounds like the one
  you were shown counts, but a word in the wrong tone doesn’t. Recognition runs
  on the device.
- If only a basic Chinese voice is installed, Zili offers to help you download
  an Enhanced or Premium one, which pronounces words and sentences far more
  clearly. It walks you through the steps in Settings, with screenshots, and
  lets you hear the new voice as soon as it arrives. Choose Remind Me Later to
  be asked again next time, or Don’t Remind Me to stop being asked.
- Every word in the HSK syllabus has example sentences, shown under its
  dictionary entry beside the dictionaries’ own. Open one to hear it, look up
  its words, or add it to your favorites.
- Practice Grammar lists the grammar points of each HSK 3.0 level: choose a
  level, then a point, to see its pattern and explanation, with example
  sentences you can hear.
- Practice Tones lays out the twenty tone pairs of two-syllable words. Choose a
  pair to see the words of your levels said with it, and play them to hear and
  imitate.
- The Dictionary can look a character up by its radical: choose Radicals, then a
  radical, then the character among those built on it.
- The Listening quiz draws its sentences from the HSK standard you choose. Pick
  HSK 3.0 (2026), HSK 3.0 (2021), or HSK 2.0 above the levels, and each sentence
  sits at the level of the hardest word it uses in that standard.
- Practice Sentences now holds the sentences you have favorited or missed.
  Sentences themselves are found under the words they show in use.

### ACCESSIBILITY

- Chinese is spoken with the best voice on the device rather than the basic one
  installed by default. If you have downloaded a premium or enhanced Mandarin
  voice, Zili now uses it, and the difference is considerable.
- VoiceOver no longer reads a word’s pinyin straight after its Hanzi, which
  have already been read aloud in Chinese. A reading that stands alone is still
  spoken.
- With VoiceOver, a Chinese word of more than one character now says what it is
  in your own language. The word itself is still read in Chinese, but the word
  “button” after it is not, and the hint that was left off to avoid that is
  back.
- Choosing which HSK standard or which sentences to browse no longer means
  opening a menu. In Practice, the choices sit in a row, on screen and one tap
  away.
- Flashcards honor “Prefer Cross-Fade Transitions”, dissolving to their other
  side instead of cutting to it when Reduce Motion is on.

### FIXES

- On Apple Vision Pro, a flashcard no longer flickers against the window behind
  it as it turns over.

## 1.3

### NEW

- Flashcards remember whether a word was missed with its pinyin showing or from
  the Hanzi alone. A Missed deck with pinyin brings back the words you didn’t
  know; one without it brings back the characters you didn’t recognize.

### FIXES

- Flashcards show a word with the reading and meaning the HSK syllabus teaches.
  A card for 说 now reads shuō, “to speak”, rather than shuì, “to persuade”,
  and words like 冷 and 都 no longer come up as surnames.

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
- Squeeze an Apple Pencil Pro while practicing strokes to flash the character’s
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

- The Drawing quiz now keeps a word’s characters together, in the order the word
  is written, instead of scattering them.
- Words you star while setting up a quiz now count toward the deck it deals.
- The end-of-quiz Favorites button no longer offers to add words you have
  already starred.

## 1.0

The first release. A Chinese dictionary, the HSK syllabus to work through,
sentence practice, and quizzes for recognition, stroke order, and listening.
