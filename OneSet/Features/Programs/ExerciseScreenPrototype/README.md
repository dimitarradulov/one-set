# Exercise screen prototype

Question: how should exercise records and past results appear alongside exercise guidance?

Verdict: the user selected Variant C with Records/History tabs, then approved heaviest weight as the main statistic. Estimated one-rep max and the most recent result are secondary. Remove the program/day subtitle and workout prescription summary. Keep the video placeholder and expandable technique/stopping and warmup guidance. The empty state represents the first app milestone; all sample history is fictional.

This branch preserves all three throwaway variants as the primary design reference. Production implementation should follow the approved requirements and design, rather than promote this HTML directly.

From the repository root, run:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Open http://127.0.0.1:8765/OneSet/Features/Programs/ExerciseScreenPrototype/?variant=C . Use the bottom arrows or `variant=A`, `variant=B`, and `variant=C` to compare. The Personal results dropdown switches sample history and empty states.

Validation: JavaScript syntax check and HTTP checks for the page and fonts passed. Automated visual browser verification was blocked by a browser connection failure; the user reviewed the live prototype and selected the final layout.

Estimated-max calculation and eligibility rules remain open before implementing real statistics.
