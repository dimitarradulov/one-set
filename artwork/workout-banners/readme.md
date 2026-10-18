# Workout banner collection

Delivered for [issue #28](https://github.com/dimitarradulov/one-set/issues/28), the asset-only portion of [spec #27](https://github.com/dimitarradulov/one-set/issues/27). Six new photographs were generated with the **built-in image_gen tool** on 2026-10-18; lower body retains the approved prototype squat. All seven are representative workout artwork, not exercise demonstrations.

## Delivered images

The files in `banners/` are ready for later app integration. Each is **1179 × 852 pixels**, exactly three times the archived Variant A banner's **393 × 284 pt** dimensions. They use progressive JPEG, quality 86, 4:2:0 chroma subsampling, and an embedded sRGB profile. They contain no day, title, program text, or baked-in fade.

| Theme / file | Image choice | Actual bytes | KiB |
| --- | --- | ---: | ---: |
| [general-gym.jpg](banners/general-gym.jpg) | Empty gym with free weights, bench, and cable machine; full-body and universal fallback | 169,754 | 165.8 |
| [upper-body.jpg](banners/upper-body.jpg) | Standing lifter beside dumbbell rack; chest, shoulders, and arms together | 117,799 | 115.0 |
| [lower-body.jpg](banners/lower-body.jpg) | Approved male barbell-squat photograph | 123,859 | 121.0 |
| [chest-push.jpg](banners/chest-push.jpg) | Incline dumbbell press | 126,659 | 123.7 |
| [back-pull.jpg](banners/back-pull.jpg) | Cable row viewed from behind | 144,030 | 140.7 |
| [shoulders.jpg](banners/shoulders.jpg) | Upright seated dumbbell shoulder press | 124,481 | 121.6 |
| [arms.jpg](banners/arms.jpg) | Standing alternating dumbbell curl | 104,250 | 101.8 |
| **Seven delivered banners** | | **910,832** | **889.5** |

KiB means 1024 bytes. These are measured file sizes, not final App Store download measurements. The seven retained source PNGs total **14,302,569 bytes**; they are production references, separate from the JPEG handoff. The two review JPEGs total **571,508 bytes**. Only `banners/` is intended for the later bundled image collection.

## Visual review

- [Contact sheet](review/contact-sheet.jpg): all seven exact delivered crops, with each photo shown at 393 × 284 pixels.
- [Heading review](review/heading-review.jpg): the same crops with the prototype's lower-edge fade and sample day, title, and program text using OneSet's Bebas Neue and Montserrat fonts. The sample titles are review examples, not catalog assignments.

Reviewed the original photographs, the full collection of delivered crops, and every sample heading overlay. The set consistently uses charcoal industrial gyms, desaturated clothing and equipment, warm amber practical lights, and restrained editorial lighting. The general-gym crop retains both free weights and machine equipment without a person or a narrow body-part focus. The other six remain distinguishable by body orientation, framing, and movement.

All crops retain the main subject, hands, and defining equipment. The lower-body crop matches the prototype's cover positioning, preserving the lifter and feet while trimming the outer barbell at the right edge. The chest and shoulder images stay distinct through reclined versus upright bench positions. The faded samples leave faces, shoulders, and identifying actions visible above readable headings; no cropping or text overlap was found in the review sheets. No visible logos, titles, instructional annotations, or watermarks appear in the delivered photos.

The heading sheet is a raster composition for asset review, not a native app screenshot or accessibility validation. Final native text layout, long titles, Dynamic Type, VoiceOver, and other screen widths remain implementation checks under #27. No app behavior, catalog metadata, assignments, or APIs change in this delivery. As required by #28, no app build/test suite or simulator run was needed.

## Prompts and reference provenance

[prompts.json](prompts.json) retains the exact submitted prompt for each image, the original squat prompt, built-in tool mode, reference role, generation output filenames, and archive location. Every new image used [sources/lower-body.png](sources/lower-body.png) as a style and lighting reference in its own built-in call, with `transparent_background=false`. The reference was not an edit target. The tool did not expose a model identifier or seed; fresh generations are nondeterministic.

The squat PNG is a byte-for-byte copy of `OneSet/Features/Programs/WorkoutBannerPrototype/lower-squat.png` from commit `0784b73f59b9740db3c563239f10d7d73a9d6153` on branch `codex/prototype-workout-banner`. Its original prompt is in that commit's prototype `readme.md`; Variant A's sizing, positioning, and fade are in the adjacent `index.html`. [Issue #26](https://github.com/dimitarradulov/one-set/issues/26) returned HTTP 410 (deleted) during this task, so the archived prototype and #27 provide the available design provenance.

All original PNGs are retained in `sources/` for recropping and future revisions. [manifest.json](manifest.json) records each source and final file's dimensions, byte size, SHA-256, source crop rectangle, and processing settings. The lowercase theme filenames are stable handoff names; app asset identifiers and template assignments belong to later integration.

## Preparing another crop

The mechanical export used Pillow 11.3.0. For each source, cover-fit to 393:284 using the manifest's source pixel bounds, then resize directly from that source rectangle to 1179 × 852 with LANCZOS. Export RGB JPEG with `quality=86`, `subsampling=2`, `optimize=True`, `progressive=True`, and an sRGB ICC profile. Do not add the sample fade or headings to the delivered JPEGs.

The manifest's crop coordinates use a top-left origin and exclusive right/bottom edges. The source `object-position` values document the equivalent CSS cover positioning. All current crops use the full source height, so vertical positioning has no effect. Wider future layouts can be recropped from the retained source rather than enlarging or stretching the delivered crop.

Verification completed: all seven sources and seven final JPEGs decode, final dimensions and sRGB profiles match the handoff, recorded sizes and hashes match the files, the squat matches the archived Git blob, and the changed documentation's relative links resolve. Review artifacts were visually inspected. Source PNGs and review sheets remain outside the app target.
