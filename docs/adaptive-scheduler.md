# Adaptive scheduler

`AdaptiveReviewScheduler` is deterministic for the same questions, progress, and current date. Randomization is limited to answer presentation and mock-exam sampling.

## Long-term states

- **Unseen**: no attempt.
- **Learning**: an initial or ordinary failure.
- **Review**: a correct encounter awaiting spaced review.
- **Weak**: explicit “Не знаю,” reveal-before-answer, a repeated lapse, or manual hard marking.
- **Mastered**: at least four successful spaced reviews, an interval of at least 14 days, and no failure in the prior seven days.

Intervals are `1, 3, 7, 14, 30, 60` days. A correct unseen answer starts at one day. Later successes advance one step. A failure increments lapse count, clears the correct streak, removes mastery, returns to one day, and records the failure time. A weak question returns to ordinary review after three consecutive successes, so an old mistake is not a permanent punishment.

“Не знаю” and `revealedBeforeAnswer` have separate counters and never count as correct. Both enter the weak state.

## Same-session repeats

`StudySession` inserts a failed question after `6 + examNumber mod 7` other positions, giving a predictable 6–12-question gap. It never inserts it on the next screen. Normal sessions allow at most two total appearances of the question. A correct repeated answer prevents another insertion. Drill Weak Questions relaxes the cap to four.

## Smart Study composition

The first pass targets roughly 50% due learning/review items, 40% unseen items, and at most 10% due mastered maintenance. Empty pools are filled from the others. Candidate ordering is deterministic by priority and exam number.

Priority combines due lateness, current state, lapses, topic weakness, and recent successful recovery. Every selection pass enforces a 40% per-topic ceiling where the available bank permits it. Mastered items only enter as due maintenance and therefore become rare quickly.
