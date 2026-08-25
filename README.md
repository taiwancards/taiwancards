# TaiwanCards

Spaced repetition for **Taiwanese Mandarin** (臺灣華語): traditional characters, zhuyin first,
Taiwan norms. The dictionary, sentence corpus, difficulty model and pronunciation
scorer are all derived here from primary sources; every entry carries its
provenance.

## Stack

- Ruby 4.0, Rails 8.1, PostgreSQL 18
- Hotwire over importmap — no Node, no JavaScript build step
- Slim, Tailwind 4, Phlex, Propshaft
- Solid Cache in the primary database; no background worker, no Redis
- Google OAuth as the only sign-in path
- Deployed on Render from `render.yaml`; shared assets on object storage behind a CDN

Generated columns hold the sort keys; partial and expression indexes serve the
faceted lookups; derived aggregates are memoized in process in front of Solid
Cache.

## What distinguishes it

**Corpus construction, not corpus scraping.**

- Register-tagged extraction over official, legal, journalistic, academic, literary, colloquial and subtitle text
- Origin filter rejecting non-Taiwanese material: simplified-character detection, orthographic round-trip, Chinese lexicon and toponyms, Cantonese particles, erhua by bilateral window
- Every sentence placed on TOCFL and TBCL with a frequency index and an unknown-word count
- Per-row source and license; statistics-only material fits the models and is never displayed, the gate enforced in SQL on every query

**Segmentation and frequency.**

- Viterbi decoding over a Kneser–Ney bigram model with a token penalty
- EM re-segmentation; relative-entropy pruning (Stolcke 1998)
- Gold set of 510 cases; bigram over unigram at p < 1e-6 (McNemar), confirmed by a 10,000-round paired bootstrap over F1
- Frequency dispersion-corrected by deviation of proportions, per register

**Lexical relations, measured rather than inferred.**

- Synonyms and antonyms from lexicographers' annotation in both MOE dictionaries, symmetrized
- Paradigmatic neighbors by PPMI with context-distribution smoothing (α = 0.75) and shift, cosine over the sparse space; window ±2, chosen against the gold set
- Syntagmatic collocates gated by Dunning's log-likelihood (G², p < 0.001) and ranked by logDice (Rychlý 2008)
- Word sketches: collocates grouped by grammatical relation — modifier, complement, resultative, aspect, disposal 把, passive 被, classifier, paired construction

**Human-written glosses, no machine translation.**

- Per-sense, numbered in source-dictionary order, hand-checked
- Stored keyed by text, so they survive a full content rebuild
- No generated content anywhere: not in the material, not in the translations

**A pronunciation scorer written from scratch.**

- Per-syllable acoustic templates estimated from a speech corpus
- Scoring on tone contour, voice onset time, formant trajectories, fricative centroid, nasality
- Speaker normalization from a calibration pass, gated by per-syllable reliability
- Taiwanese norms modeled apart from the Beijing standard
- No cloud ASR; audio never leaves the server

**One progress model behind every screen.**

- FSRS-6 in pure Ruby, golden-tested against the reference implementation
- Six independent facets per lexeme: recognition, production, reading, listening, tone, writing
- Every trainer, deck and reader writes into the same schedule; there is no second, parallel notion of progress
- Adaptive placement test: three-parameter logistic model, posterior over a 96-point ability grid, per-axis item selection by expected information

**Character-level derivation.**

- Stroke counts and stroke sequences from CNS 11643
- Phonetic series scored by modal 廣韻 rhyme group over the members sharing a component
- Visually confusable neighbors by inverse-document-frequency weighted Jaccard over component sets
- Etymology, radical, structure and variant readings per character

**Taiwan life, not textbook life.**

- Phrasebook of slot-filled patterns for the situations of an actual day: convenience store, drink shop, breakfast shop, local eatery, MRT, clinic, parcel pickup, tenancy, typhoons
- Both halves of each exchange — what you say, and what the cashier says back
- Explicit contrast where Taiwan differs: 不會 not 不客氣, 不用 not 不要, 結帳 not 買單, 計程車 not 出租車, 捷運 not 地鐵
- Every pattern linked into the dictionary through the same segmenter the corpus uses

**Trainers.**

- Stroke order and handwriting recognition, zhuyin keyboard, zhuyin-by-ear, tone discrimination
- Phonetics drill from the syllable inventory, numerals, Cangjie, text annotation
- Decks built from your own pasted text, a file, or song lyrics

## Method and material

The distributional and typological work follows the author's 2015 master's thesis
in computational linguistics and quantitative typology. The classical estimators
— Kneser–Ney, PPMI with context smoothing, Dunning's G², logDice, deviation of
proportions — are kept because on a corpus of this size they still measure best:
trigrams, deeper entropy pruning and truncated SVD were each tested against the
gold set and rejected on the numbers.

The corpus is Taiwanese Mandarin, not Chinese text converted to traditional
characters. Sources are Taiwan-originated, or kept only after the origin filter
and manual review. Frequency, segmentation and difficulty are fitted on that
material.

## Run it

Starts with an empty database: the full interface, no content. Enough to read the
code, run the tests and see the UI.

### macOS

```bash
brew install ruby postgresql@18 just
brew services start postgresql@18
```

### Ubuntu

```bash
sudo apt install -y ruby-full postgresql libpq-dev build-essential just
sudo systemctl start postgresql
```

### Both

```bash
bundle install
cp .env.dev .env                 # fill in SECRET_KEY_BASE and PGPORT
bin/rails db:prepare
just dev                         # or: bin/dev
```

Open <http://localhost:3000>.

`just dev` runs Puma, the Tailwind watcher and an optional ngrok tunnel. Without
`NGROK_DOMAIN` in `.env`, or without ngrok installed, the tunnel prints one line
and stops; everything else runs as usual on localhost.

`bin/rails secret` generates `SECRET_KEY_BASE`. `PGPORT` is `5432` by default.
`.env.dev` lists every variable, split into required and optional; unset optional
variables degrade to a no-op.

## Checks

```bash
bin/rspec                        # tests
bin/rubocop                      # style
bin/brakeman                     # static analysis
bin/bundler-audit                # dependency advisories
bin/rails site:check             # site/ still matches the pages it is built from
bin/ci                           # all of the above
just --list                      # task shortcuts
```

`site/` holds the static marketing pages, rendered from the same Slim views the
application serves and deployed by a separate Render static service from this
repository. Regenerate them with `just site` whenever those pages change; `bin/ci`
fails if the committed output has drifted.

## Layout

| Path                                               | Contents                                                       |
| -------------------------------------------------- | -------------------------------------------------------------- |
| `app/services/fsrs/`                               | FSRS-6 scheduler                                               |
| `app/services/huayu/`                              | zhuyin, tone sandhi, segmentation, level projection, importers |
| `app/services/pronunciation/`                      | acoustic analysis, templates, thresholds, drills               |
| `app/services/lexemes/`, `study/`                  | facets, activation, reviews, search, session building          |
| `app/services/learn/`, `onboarding/`, `placement/` | what to show next, roadmap, placement test                     |
| `app/services/phrases/`                            | phrasebook resolution against the dictionary                   |
| `app/services/intro/`                              | the guided tour, driven by `config/intro_map.yml`              |
| `app/services/deploy/`, `install/`                 | content transfer and local rebuild                             |
| `app/models/`                                      | `Lexeme`, `LexemeMemory`, `LexemeReview`, `Collection`, `User` |
| `lib/tasks/`                                       | rake orchestration for imports and deployment                  |

## Related repositories

| Repository                                                    | Visibility | Contents                                                                                     |
| ------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------- |
| [taiwancards/corpora](https://github.com/taiwancards/corpora) | public     | offline pipeline: collection, segmentation, frequency and dispersion, statistical evaluation |
| [taiwancards/data](https://github.com/taiwancards/data)       | private    | derived dictionaries, graded word lists, glosses, acoustic templates                         |
| [taiwancards/docs](https://github.com/taiwancards/docs)       | private    | design notes, methodology, measurements                                                      |

Data is private because it is the product: glosses, graded lists, register
profiles and acoustic templates are output, not input. Sources are credited under
`/licenses`.

## License

No license granted for this source code; all rights reserved. The data
repositories are separate and licensed per source, as recorded under `/licenses`.

Questions and license enquiries:
[support@taiwancards.app](mailto:support@taiwancards.app)
