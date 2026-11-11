# =============================================================================
# build_site.R — render the workshop website into docs/
#
# From the repository root (data/ and results/ must be present):
#
#     Rscript setup/build_site.R
#
# Renders the home page (site/index.Rmd), the Introduction and Modules 1-3
# from the saved results in results/, adds a navigation bar to every page,
# and writes everything to docs/. Commit docs/ and push: the GitHub Actions
# workflow (.github/workflows/pages.yml) publishes it to GitHub Pages.
#
# GitHub's servers cannot run the modules (they need the data and minutes of
# computation), so the site is always built here and only published there.
# =============================================================================

if (!file.exists("setup/build_site.R")) {
    stop("Run this script from the repository root. Current directory: ", getwd())
}
if (!file.exists("data/afternoon_mvp.rds")) {
    stop("data/ is missing. Run setup/download_data.R first.")
}

pages <- c("site/index.Rmd",
           "vignettes/00_introduction.Rmd",
           "vignettes/01_phispace_annotation.Rmd",
           "vignettes/02_pseudotime.Rmd",
           "vignettes/03_nnet.Rmd")

out <- normalizePath("docs", mustWork = FALSE)
unlink(out, recursive = TRUE)            # start clean: no stale pages or figures
dir.create(out)
Sys.setenv(SCW_RESULTS = normalizePath("results"))
navbar <- normalizePath("site/navbar.html")

for (p in pages) {
    message("Rendering ", p, " ...")
    t0 <- Sys.time()
    rmarkdown::render(
        p,
        output_dir = out,
        quiet = TRUE,
        envir = new.env(),
        output_options = list(
            # figures as files and JavaScript libraries shared in docs/libs,
            # instead of everything embedded in each page
            # (absolute: a relative lib_dir is resolved from the source file)
            self_contained = FALSE,
            lib_dir = file.path(out, "libs"),
            includes = rmarkdown::includes(before_body = navbar)
        )
    )
    html <- file.path(out, sub("\\.Rmd$", ".html", basename(p)))
    if (any(grepl("are not evaluated", readLines(html, warn = FALSE)))) {
        stop(basename(p), " rendered without running its code (missing data or ",
             "saved results?). The site was not completed.")
    }
    message(sprintf("  done in %.0f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

invisible(file.create(file.path(out, ".nojekyll")))   # serve files as they are
size <- sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))) / 1e6
message(sprintf("\nSite built in docs/ (%d files, %.1f MB).",
                length(list.files(out, recursive = TRUE)), size))
message("Commit docs/ and push to publish it.")
