# Workshop VM setup checklist

Target VM: Windows, 8 cores, 32 GB RAM, 128 GB disk (accessed in Chrome / Edge).
Once this checklist passes, the organisers clone the VM for every participant,
so **whatever state the VM is in at the end is what participants get.**

Total time: roughly 45–60 min (most of it is waiting for downloads).

---

## 1. Base software

Open PowerShell and check what is already installed:

```powershell
R --version        # or: & "C:\Program Files\R\R-*\bin\R.exe" --version
git --version
```

| Software | Needed version | Download |
|---|---|---|
| R | **4.6.x** (Bioconductor 3.23) | <https://cran.r-project.org/bin/windows/base/> |
| RStudio Desktop | latest | <https://posit.co/download/rstudio-desktop/> |
| Git for Windows | any (optional, see step 2) | <https://git-scm.com/download/win> |

- If the pre-installed R is older than 4.6, install R 4.6.x alongside it.
  In RStudio, *Tools → Global Options → General → R version* select 4.6.
- **Rtools is not needed.** Every package installs as a Windows binary, and
  PhiSpace and NeighbourNet are pure R.
- Windows Server may block downloads in Edge ("IE Enhanced Security").
  Use Chrome, or turn that setting off in Server Manager.

## 2. Get the workshop repository

Put it on a **short path** to avoid Windows' 260-character path limit.
Git is not needed. Paste this into the R console (RStudio or RGui):

```r
root <- "C:/workshop"
dir.create(root, showWarnings = FALSE)
zip <- file.path(tempdir(), "scWorkshop.zip")
download.file("https://github.com/mao-lab-org/scWorkshop/archive/refs/heads/main.zip",
              zip, mode = "wb")
unzip(zip, exdir = root)
src <- file.path(root, "scWorkshop-main"); dst <- file.path(root, "scWorkshop")
dir.create(dst, showWarnings = FALSE)
file.copy(list.files(src, full.names = TRUE, all.files = TRUE, no.. = TRUE),
          dst, recursive = TRUE, overwrite = TRUE)
unlink(src, recursive = TRUE)
```

**To pick up later changes**, re-run the same block. It overwrites the code
files and leaves `data/` and `results/` alone. (It does not delete files
that were removed from the repository.)

If Git is installed, `git clone https://github.com/mao-lab-org/scWorkshop.git`
into `C:\workshop` does the same thing.

Double-click `C:\workshop\scWorkshop\scWorkshop.Rproj` to open it in
RStudio. All commands below are typed in the RStudio **Console**. They assume
the working directory is the repository root, which is what opening the
`.Rproj` file sets.

## 3. Install R packages (~15–25 min)

```r
source("setup/install_packages.R")
```

It ends with `All NN packages installed and loadable.` If it stops with an
error, re-run it; it skips anything already installed.

## 4. Download data (~5–15 min, 2.7 GB)

```r
source("setup/download_data.R")
```

This creates `data/` (query and reference) and `results/` (pre-computed
caches for the slow steps). The script checks the download's MD5 checksum.

## 5. Check the setup (~1–2 min)

```r
source("setup/check_setup.R")
```

It must end with `All checks passed`.

## 6. Dry run

In the RStudio **Terminal** tab (not the Console), from the repository root:

```bash
Rscript setup/dry_run.R           # with caches: what participants experience
Rscript setup/dry_run.R --fresh   # recompute everything: tests every code path
```

Both must end with every module `OK`. Write down the timings from
`--fresh`; they tell us which steps need to stay cached during the session.

Reference timings from a dry run on a Mac (Apple Silicon), 11 Nov 2026:

| Module | Cached | `--fresh` |
|---|---|---|
| 01 Φ-Space | 40 s | 118 s |
| 02 Pseudotime | 36 s | 237 s |
| 03 NeighbourNet | 16 s | 101 s |
| **Total** | ~1.5 min | ~7.6 min (peak memory ~10 GB) |

The Zenodo caches were made with PhiSpace 1.1.0; the workshop installs
PhiSpace 0.99.0 (the latest, `mao-lab-org/PhiSpace`). A fresh run with 0.99.0
matched the caches: Φ-Space scores agreed to 1e-8, pseudotime ranks were
identical, and the same meta-network was selected. So the caches are kept.
Open the HTML files in `dry_run/` and skim the figures.

Then walk through the participant path once by hand: open
`vignettes/00_introduction.Rmd` and run the chunks one by one with
*Run → Run All Chunks Above* or Ctrl+Shift+Enter. Repeat for 01, 02 and 03.

## 7. Clean up before handing the VM back

```r
unlink(c("downloads", "results_fresh", "dry_run"), recursive = TRUE)
```

- Keep `data/` and `results/`. Participants need both.
- In RStudio: *Session → Clear Workspace*, close all open files, then
  *Tools → Global Options → General*: untick "Restore .RData" and set
  "Save workspace on exit" to **Never**.
- Optional: put a desktop shortcut to `C:\workshop\scWorkshop\scWorkshop.Rproj`.
- Close RStudio and tell the organisers the VM is ready to clone.
