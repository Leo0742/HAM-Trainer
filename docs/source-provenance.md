# Source provenance and audit

## Documents

The reference PDF is a 233-page 2015 edition of A. N. Zamoroka's exam handbook. Its question appendix contains 426 numbered questions, exact answer choices, and embedded figures. The newer 104-page guide is titled “Радиолюбитель второй категории — теория и 405 вопросов,” revision 1 August 2026. It explicitly identifies the second-category ranges, 30-question exam, 25/30 threshold, beginner theory, topics, types, correct-answer text, explanations, review tables, and source-page callouts for diagrams.

The import audit found exactly 405 numbered guide entries for the required ranges and all 426 reference entries. The selected set is 1–38, 47–98, 100–374, and 387–426. Generated provenance records the actual page in each supplied PDF, not an inferred external edition page.

## Source priority

- Newer guide: selection, topic, question type, learning structure, terminology, correct-answer text, and explanation.
- Reference: exact question wording, complete options, original question number, and required figure pages.

Question 201 exposes a real wording mismatch: the guide states “U или E,” while the supplied reference option contains `U`. The app selects the actual reference option and preserves the mismatch in `legalHistoricalNote`.

## Figures and copyright separation

The original PDFs are not copied into the project. The importer renders only the 14 local reference pages needed by 24 figure-dependent selected questions and stores them under `Content/diagrams/`. These assets are for the locally built study application and should not be published blindly. Original diagrams created in the future should use a separate naming/source field.

Every question has both reference and explanation document/page metadata. `source-map.json` makes later correction audits possible without loading the full question bank.
