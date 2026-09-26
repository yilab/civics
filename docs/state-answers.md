# State-specific answers

Status: v1 in progress (started 2026-09-26).

## Problem

Four civics questions have answers that depend on where the applicant lives:

| Q | Question | Depends on |
|---|---|---|
| 23 | Who is one of your state's U.S. senators now? | state |
| 29 | Name your U.S. representative. | congressional district |
| 61 | Who is the governor of your state now? | state |
| 62 | What is the capital of your state? | state |

Before this change the app spoke "This answer depends on your state. Look up …" for all four. In a hands-free study loop that is the one place where the user hears no answer to repeat, and the practice test could ask a question the user had no way to grade.

USCIS rule ([testupdates](https://www.uscis.gov/citizenship/testupdates)): "You must answer the question with the name of the official serving at the time of your naturalization interview."

## Decisions

- **Ask for the state, never use location.** A manual picker with 56 places: 50 states, D.C., and 5 territories (PR, GU, VI, AS, MP). USCIS asks about where you live, not where your phone is, and location access would break the no-permissions privacy promise.
- **District only where needed.** Q29 needs the congressional district. The 6 single-seat states (AK, DE, ND, SD, VT, WY) and the 6 non-voting jurisdictions (D.C. and the territories) fill it in automatically; everyone else picks from "District N · Name", with a link to house.gov's Find Your Representative.
- **Names stay in English in every study language.** Only the surrounding sentence is translated. The interview is in English, and transliterating ~600 names into 10 languages cannot be kept correct. (The four national officials, Q30/38/39/57, keep their existing transliterations.)
- **Practice test skips Q23/29/61/62 until a state is set.** Once set, they are asked like any other question.
- **Changing the state or district unmarks those questions as known**, since their answers changed.
- **Stay offline.** The data ships inside the app; nothing is fetched and the chosen state never leaves the device.

## Design

**One personalize step per platform.** Every platform reads one question list (Android/Apple `QuestionRepository`, web `QUESTIONS`) for the study deck, the practice test, and the Flashcards and Questions tabs. A small personalize step fills in answer, spoken text, and note — in English and every translation — for the chosen place, district, and today's date. The engine, karaoke, and the five tabs are otherwise unchanged. The three implementations are kept in parity like `engine.js` ↔ `StudyEngine.kt`.

**What is spoken**

| Q | Answer |
|---|---|
| 23 | "Either one: A, or B." (only one is required) · D.C./territories: "There are no U.S. senators for …" |
| 29 | the representative · D.C./territories: the non-voting Delegate or Resident Commissioner · empty seat: "This seat is vacant right now. Check house.gov before your interview." |
| 61 | the governor · D.C.: "D.C. does not have a governor." |
| 62 | the capital · D.C.: "D.C. is not a state and does not have a capital." |
| no state set | "This answer depends on your state. Choose your state in Settings to hear your answer." |

**Dated entries.** Every senator, representative, and governor carries `from`/`until` dates. The app picks whoever is serving today, so a release that already contains election winners switches each name on its own start date. If a term has ended and the data has no successor, the app keeps the last name but says it may be out of date and to check before the interview.

## Data

- Source of truth: `web/data/officials-source.json`. Congress (senators, representatives, delegates) is refreshed from the public-domain [unitedstates/congress-legislators](https://github.com/unitedstates/congress-legislators) dataset; governors, capitals, and House seat counts are maintained by hand. The sentence templates for all 11 languages live in the same file.
- Generated, checked in, never edited by hand (same pipeline as the question bank, `npm run sync`):
  - `android/app/src/main/assets/officials.json`
  - `apple/Civics/Civics/Resources/officials.json`
  - `web/data/officials.generated.js`
- The generator fails on anything missing: a place without a capital or governor entry, a state whose seats don't add up, a template missing in any language.

## Keeping it current

The 2026 midterms (Nov 3) change many answers in January 2027.

- **Before Nov 3:** ship v1 with today's officials.
- **Late Nov–Dec:** once results are certified, add the winners with their start dates and ship one release. Congress starts Jan 3; governors' start dates vary by state; special-election winners can be sworn in early.
- **Jan 3, 2027:** the Speaker (Q30) is only known after the House votes — plan a quick update that week. At least six states (CA, MO, NC, OH, TX, UT) use new district maps from Jan 3, so district numbers change even for people who didn't move; those users need to pick their district again (not yet built).

## Later (not in v1)

- Let the user type a name themselves (vacancies, appointments, a recent move).
- A one-time "your answer to Q29 changed" notice when a dated entry switches.
- Re-ask the district in redistricted states after Jan 3, 2027.
- Date-switching for the national four (Q30/38/39/57), including their translated names.
- ZIP-code district lookup, if the district list proves hard to use.
