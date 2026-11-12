# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Materials for a 3-hour BiocAsia 2026 workshop, "Modelling continuous cell states using
scRNA-seq data". It is adapted from the afternoon session (Modules 5–7 there; Modules 1–3
here) of the Phipson Lab workshop
([phipsonlab/single_cell_workshop](https://github.com/phipsonlab/single_cell_workshop)).
The materials are R Markdown vignettes run in RStudio. Data: Sim et al. 2021 human heart
snRNA-seq (foetal / young / adult), with the Gao et al. 2026 left-ventricle atlas as the
Φ-Space reference.

| Module | File | Methods |
|---|---|---|
| Intro | `vignettes/00_introduction.Rmd` | Sim et al. 2021, why continuous states, data tour (Seurat only) |
| 1 | `vignettes/01_phispace_annotation.Rmd` | PhiSpace soft annotation (cell type + age group) |
| 2 | `vignettes/02_pseudotime.Rmd` | slingshot, destiny DPT on PCA vs Φ-Space embeddings |
| 3 | `vignettes/03_nnet.Rmd` | NeighbourNet cell-specific co-expression networks |

## The participant-VM constraint (read first)

Participants use cloned copies of one Windows Server VM: R 4.6.1, Bioconductor 3.23,
8 cores, 32 GB RAM, **no git**. The VM was set up and checked on 11 Nov 2026 by following
`setup/VM_SETUP.md`.

- **Installed packages and the `data/` + `results/` files are frozen once the organisers
  clone the VM.** Material changes must use only what is already installed. If a change
  truly needs a new package, tell the user straight away: it has to be installed on the
  setup VM *before* cloning. Also add it to `setup/install_packages.R` and the list in
  `setup/check_setup.R`.
- **Code is not frozen.** On the day, participants re-run the repo-download snippet in
  `setup/VM_SETUP.md` (step 2). It overwrites the code from GitHub `main` and leaves
  `data/` and `results/` alone. So anything pushed to `main` before the session reaches
  participants.
- The workshop helper `R/nnet_viz.R` is deliberately a sourced script, not a package,
  for this reason.
- The repo-download snippet only adds and overwrites files. After the renumbering, the
  VM still had the old `vignettes/05_*.Rmd`, `06_*.Rmd`, `07_*.Rmd`; they must be deleted
  on the VM before cloning (command in the user's notes from 11 Nov; check with the user
  whether that is done). Whether the organisers have cloned the VM yet is unknown: ask.

## Commands

Run from the repository root. `data/` and `results/` must be present; they are gitignored.

```bash
Rscript setup/check_setup.R          # package versions, data files, ~5 s smoke test of every method
Rscript setup/dry_run.R              # render Intro + Modules 1-3 using the caches in results/ (~1.5 min)
Rscript setup/dry_run.R --fresh      # recompute everything into results_fresh/ (~8 min, ~10 GB RAM)
Rscript setup/build_site.R           # build the website into docs/ from the caches (~1.5 min)
```

Render a single module, writing the HTML outside `vignettes/`:

```bash
Rscript -e 'Sys.setenv(SCW_RESULTS = normalizePath("results")); rmarkdown::render("vignettes/03_nnet.Rmd", output_dir = "dry_run")'
```

`dry_run/`, `results_fresh/` and `downloads/` are gitignored scratch output.

## Website (GitHub Pages)

<https://mao-lab-org.github.io/scWorkshop/>. GitHub's runners have no data, so the site
is **built locally and only published by CI**:

- `setup/build_site.R` renders `site/index.Rmd` (home page) and the four vignettes into
  `docs/` with `self_contained = FALSE`, so figures are separate files and the JavaScript
  libraries are shared in `docs/libs`. It wipes `docs/` first, and stops if any page
  rendered without running its code.
- `site/navbar.html` is injected into every page via `includes(before_body = ...)`. A
  small script moves it to the top of `<body>`, because R Markdown places included HTML
  inside the content column next to the floating TOC.
- There is deliberately no `_site.yml` in `vignettes/`: it would make RStudio's Knit
  button build the whole site.
- `.github/workflows/pages.yml` uploads `docs/` on pushes that change it (no R in CI).
  Pages source must be set to "GitHub Actions" in the repo settings.
- After editing a vignette, rebuild the site, commit `docs/` with the change, and push.

## How the modules fit together

- **Modules form a chain through cache files.** Module 1 writes
  `results/05_phispace_query.rds`, which Module 2 reads. Module 2 writes
  `results/06_cm_pseudotime.rds`, which Module 3 reads. Each slow step is wrapped in an
  "if the cache exists, load it; otherwise compute and save" block. With caches present,
  a module only re-plots.
- **Cache files keep the original numbering** (`05_*.rds`, `06_*.rds`, `07_*.rds` for
  Modules 1, 2, 3). They are frozen on the VM and in the Zenodo/Dropbox zips, so don't
  rename them; only the module files and titles were renumbered.
- **Results directory:** every vignette uses `results_dir <- Sys.getenv("SCW_RESULTS", "../results")`.
  Paths are relative to `vignettes/`, because knitr runs from the Rmd's folder.
  `dry_run.R --fresh` points `SCW_RESULTS` at an absolute `results_fresh/` path.
- **Silent skip:** each vignette's setup chunk sets `eval = data_ok`. If the input
  file is missing, the module renders without error but runs no code. After rendering,
  check the HTML does not contain "are not evaluated".
- **Data and caches** come from Zenodo record 20017845 (`afternoonSession.zip`, 2.7 GB);
  `setup/download_data.R` fetches it. Zenodo is very slow (~340 KB/s), so the VM was
  filled from a Dropbox copy instead (`~/Dropbox/scWorkshop_VM/scWorkshop_data.zip`,
  MD5 `70343d10dc8a49b10d8617e37a41dbcb`). The user's old clone at
  `~/Documents/GitHub/single_cell_workshop/{data,results}` holds the same files.
- **The caches were made with PhiSpace 1.1.0 and are kept on purpose.** A fresh run with
  PhiSpace 0.99.0 and Seurat 6.0.0 reproduced them: scores within 1e-8, identical
  pseudotime ranks, the same selected meta-network.

## Package pins and gotchas

- **PhiSpace:** use the latest version from `mao-lab-org/PhiSpace`, not the old
  `jiadongm/PhiSpace`. It is 0.99.0, pinned by commit SHA in `setup/install_packages.R`.
  `getClass()` was renamed `getLabels()`. NeighbourNet is pinned the same way. To move a
  pin, update the SHA and re-run `dry_run.R --fresh`.
- **Optional dependencies are not installed automatically.** Packages a method lists
  under `Suggests` are skipped by `install()` but some are needed at run time. slingshot
  needs `DelayedMatrixStats`, which was missed until the VM check failed. List such
  packages explicitly in `install_packages.R`.
- **Seurat 6.0.0** (released 7 Nov 2026) is on the VM and passes the full fresh run.
- **NeighbourNet's "p.val" is inverted:** higher means a stronger edge, and an edge is
  shown when the value is above `cutoff`.
- **Don't change the user's main R library to test things.** It is the user's working
  environment. Install into an isolated library instead (`R_LIBS=<scratch dir> Rscript ...`).

## `R/nnet_viz.R` (Module 3's interactive network view)

- `nnet_tables(seu, i, meta.network = TRUE)` returns `nodes` and `edges` data frames.
  It does not recompute anything. It calls `NeighbourNet::visualise.network()` and reads
  the network out of the returned ggraph:
  - nodes, layout and TF modules from `attr(p$data, "graph")` and `p$data`;
  - node weights from the scatterpie layer `p$layers[[2]]`, matched to nodes by x/y
    position, because its group ids are not in node order.
  
  This is fragile by design and will break if NeighbourNet's plot structure changes.
- `nnet_vis(tabs)` draws the tables with visNetwork and adds an HTML legend
  (`.nnet_legend()`) with `htmlwidgets::appendContent`.
- **Widget height:** leave `height = NULL` so htmlwidgets picks a height for each
  context through the sizing policy:
  - browser and RStudio Viewer: `calc(100vh - 200px)`, the window minus room for the
    legend;
  - knitr (knitted HTML and RStudio's inline chunk output): a fixed 550 px.
  
  Don't use htmlwidgets' fill mode, which pushes the legend off screen. Don't use one
  fixed height either: on a large screen the network then fills only the top part of
  the window.
- **vis.js data-frame columns:** use dotted nested names only. A plain `color` or
  `arrows` column next to `color.border` or `arrows.to.type` stops the widget rendering.
  To debug, render with `htmlwidgets::saveWidget()` and read the browser console.
- **Design rules:** colour means TF module only (targets are neutral white); edges
  without prior knowledge are dashed (undirected), as in NeighbourNet's static plot,
  with dash length scaled to edge width; prior-supported edges are solid with an arrow
  or T-bar; genes with no edge above the cutoff are greyed out; layout is fixed so
  meta-networks compare directly.
- **Not yet tested** on cell-specific networks (`meta.network = FALSE`) or on data where
  receptor/pathway layers appear.
- **After the workshop,** the plan is to move it into NeighbourNet together with a
  refactor of `visualise.network()` (compute tables, then draw). Don't make NeighbourNet
  depend on a separate viz package; that would be a circular dependency. This is now
  NeighbourNet PR #2 (see below); keep the two renderers' conventions in sync.

## Open work on the materials

Proposed 180-minute timetable:

| Time | Block |
|---|---|
| 0:00–0:15 | Introduction (data, biological question) |
| 0:15–1:05 | Module 1 |
| 1:05–1:15 | Break |
| 1:15–2:00 | Module 2 |
| 2:00–2:50 | Module 3 |
| 2:50–3:00 | Wrap-up |

### Status (end of 11 Nov 2026)

Done: modules renumbered 1–3; Introduction (`00_introduction.Rmd`) written; Module 2
trimmed; Module 3 has an interactive network section with 3 exercises; website live; all
four files pass `dry_run.R` (cached and `--fresh`).

**Next, led by the user:** their own manual edits and review of the vignettes, then
slides. Their edits take precedence: before changing a vignette, check `git diff` /
`git log` for their recent changes and don't overwrite them. After any vignette change,
run `Rscript setup/dry_run.R`, then `Rscript setup/build_site.R`, and commit `docs/` with
the change.

Notes for that work:
- The Introduction's general background on cardiomyocyte maturation (marked with a
  `TODO(Jiadong)` comment in `00_introduction.Rmd`) is not from Sim et al. 2021 and
  needs the user's check. Facts from the paper come from its abstract (PMID 33682422).
  The Gao et al. 2026 reference entry still lacks a DOI and author list.
  BiocAsia participants have not done the original morning session, so no module may
  assume it.
- Text must describe what the rendered output actually shows. Two claims inherited from
  the original workshop were wrong and have been rewritten (Module 2). Check numbers in
  the rendered HTML before writing about them.
- Module 2 is trimmed: the main path has the Φ-Space score, one slingshot run and one DPT run
  (all on Φ-Space), compared with each other and with donor stage, then the
  clustering-sensitivity figure. PCA runs and the method × embedding comparison are in
  "Going Further (Optional)" after the handoff save, so they never change
  `06_cm_pseudotime.rds`. Findings the text relies on: all pseudotimes put foetal first but
  don't separate young from adult; the slingshot runs differ in lineage count (6–7
  unsupervised vs 2–3 Φ-Space cell types) yet agree with stage about equally (ρ ≈ 0.73).
- **Slides:** adapt the old `afternoon_30min_xaringan.Rmd` from the original repo
  (`~/Documents/GitHub/single_cell_workshop/`). Follow the slide conventions referenced in
  the user's global CLAUDE.md (read that SKILL.md first). Renumber to Modules 1–3, add an
  Introduction section, and make "run the repo-download snippet" the first instruction on
  the opening slide. Before reusing the old slides' claims about results, check them
  against the current rendered modules.
- 12 Nov: exercises with folded `<details>` solutions added (Intro 1, Module 1 three plus a
  double-dipping simulation, Module 2 the optional clustering extension, Module 3 six). Module 2's
  clustering pitfall now comes after the handoff save. Module 3 now uses
  `meta.network$npca.loadings` as meta-network cell weights: `meta.network$pcs` is an
  ordinary PCA whose first column is the negative of meta-network 1's weights.
  Meta-network 1 = foetal pattern, 2 = post-natal pattern. Module 1 runs `PhiSpace()` live
  (~2 s) instead of loading the cache.
- Deferred (user's call): moving
  `pt_phi_score` from Module 2 into Module 1 (Module 3 reads it from Module 2's handoff
  file, so moving it means saving it in Module 1's handoff too).
- Rehearse and fit the timing.
- Later: switching the site to a Quarto website with "freeze" (nicer site, smaller
  diffs) was discussed and postponed until after the workshop.

## NeighbourNet pull request (separate repo)

[meiosis97/NeighbourNet#2](https://github.com/meiosis97/NeighbourNet/pull/2) adds
`visualise.network(..., interactive = TRUE)`. It is open, waiting for Yidi's review.

- Local clone: `~/Documents/GitHub/NeighbourNet`, branch `interactive-visualise`;
  remotes `origin` = the user's fork (`jiadongm/NeighbourNet`), `upstream` =
  `meiosis97/NeighbourNet`. The user pushes; Claude cannot.
- `dev/` in that clone is excluded through `.git/info/exclude` and holds:
  - the regression data (`fixtures/`, ~6 GB);
  - `capture.R` / `compare.R`: static-output baseline vs `6a8de81`, 13 configurations, must
    stay identical;
  - `render_interactive.R`, `stress.R`;
  - `rlib/`: an isolated R library with roxygen2 7.3.3, testthat, pkgload, rcmdcheck and
    the branch's build. Use `R_LIBS=$PWD/dev/rlib`; reinstall with
    `R CMD INSTALL --no-test-load -l dev/rlib .`;
  - `pr/`: PR description and comment drafts.
- Tests: `R_LIBS=$PWD/dev/rlib Rscript -e 'testthat::test_local(".")'` (9 tests, ~11 s).
- Changes made in review: edges without prior knowledge are dashed (Yidi's request; dash
  length scales with width), and widget height follows the window in browser/Viewer.
  `R/nnet_viz.R` in this repo mirrors both.
- Problems already in the package, listed in the PR rather than fixed: no `License`, ggplot2/RColorBrewer/
  SeuratObject not in Imports, examples use an undefined `seurat.obj`, `.Rbuildignore`
  is itself gitignored (so the package bundles `misc/` and 45 MB of data),
  `receptor.activity = "dist"` errors (indexes by gene name; rows are `g1.<gene>`),
  igraph deprecation warnings.
- The workshop VM pins NeighbourNet at `6a8de81`; keep using `R/nnet_viz.R` for the
  workshop. After the PR is merged, Module 3 can switch to `interactive = TRUE`.

## Git

Remote: `github.com/mao-lab-org/scWorkshop` (public). Claude's shell has no GitHub
credentials, so commit locally and ask the user to `git push`.
