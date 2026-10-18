# Menu navigation prototype

Throwaway browser prototype on `prototype/menu-navigation`. Production app files are unchanged.

Question: do Program + History + Settings remain clear through workout and exercise browsing, and which Settings hierarchy is easiest to use?

Run from the repository root:

```sh
python3 OneSet/App/MenuPrototype/serve.py
```

Open [the preview](http://127.0.0.1:8767/OneSet/App/MenuPrototype/?variant=A).

- `?variant=A`: grouped Settings sections, the recommended starting point.
- `?variant=B`: one continuous Settings list.
- `?variant=C`: nested Training and Account categories. These are an exploratory alternative with additional navigation depth, not an approved route change.
- Add `&page=settings`, `&page=workout`, `&page=exercise`, or `&page=history` to open those screens directly.

The floating switcher and left/right arrow keys cycle layouts and open Settings for comparison. The workbench shortcuts return to the other screens. The three bottom tabs open Program, History, and Settings independently. Program opens the current program screen; Settings has its own navigation stack and is not accessed through Program. Switching tabs preserves each tab's stack and scroll position, including the selected training week and exercise performance panel. All unfinished Settings destinations are explanatory placeholders. Setup-upload state, retry, sign out, and Start workout are local demonstrations with no API calls or durable effects.

Real catalog fixtures come from `worker/catalog/programs/10-machine-full-body.yaml`; typography, colors, and banner images reuse the app's assets. Sample preferences are kg and three training days per week. Performance is empty, with no invented personal records.

Browser blur and vector symbols approximate native iOS controls. They are not evidence of the final Liquid Glass rendering; the production implementation must use standard SwiftUI navigation and tab controls. The preview is restricted to local hosts and is not part of production navigation.

Verdict: the user selected **Variant A — grouped Settings sections** after reviewing the prototype. Training contains Units, Training frequency, and Rest alerts; Downloads contains Downloaded videos; Account contains Subscription, Account deletion, and Sign out. Headings group directly reachable rows without adding navigation depth. Variants B and C remain archived alternatives and are not selected for implementation. The selection settles the Settings hierarchy. The subsequent navigation clarification makes Settings an independent third tab alongside Program and History; the grouped Variant A content is unchanged.

[Issue #31](https://github.com/dimitarradulov/one-set/issues/31) records the implementation spec. Preserve this throwaway prototype on its branch; implement the selected behavior using native SwiftUI controls rather than promoting the browser demo into the app.

Browser previews: [A](screenshots/settings-a.png), [B](screenshots/settings-b.png), [C](screenshots/settings-c.png).

Manually exercised in Chrome: Program → workout → exercise; global History and return with the same exercise-performance selection; back navigation; all six Settings placeholders; nested Training and Account; stub sign out and setup retry; variant arrows and keyboard cycling. Inspected desktop and 393 × 852 browser layouts. Browser console reported no errors or warnings during this pass. No native app build or simulator validation was run because this branch changes only the throwaway browser prototype.

Three-tab clarification verification: independently switched Program → exercise → Settings → Units → Program → History → Settings and retained both the exercise performance panel and Settings placeholder. Checked all six placeholders with Settings selected, refreshed the three layout screenshots, and inspected the 393 × 852 browser layout. No browser console errors or warnings were observed.
