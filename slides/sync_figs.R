# Copy the figures the slides use into slides/figs/.
#
# Quarto preview (RStudio's Render button) serves only this folder, so the
# slides cannot load images from ../docs or ../figs. Instead, each .qmd refers
# to a path under figs/, and this script fetches it from the repository:
#
#   figs/docs/<path>  <-  ../docs/<path>   (figures from the rendered website)
#   figs/<path>       <-  ../figs/<path>   (method and diagram images)
#
# Quarto runs it before every render or preview (pre-render in _quarto.yml).
# Rebuild the website first (setup/build_site.R) to pick up new figures.

qmds <- list.files(".", pattern = "\\.qmd$")
txt <- unlist(lapply(qmds, readLines, warn = FALSE))
refs <- unique(unlist(regmatches(
    txt, gregexpr("(?<![./\\w])figs/[^)\"' ]+\\.(png|jpe?g|svg|gif)", txt, perl = TRUE)
)))

missing <- character()
for (dest in refs) {
    src <- file.path("..", dest)                       # figs/x  -> ../figs/x
    if (startsWith(dest, "figs/docs/")) {
        src <- file.path("..", sub("^figs/", "", dest)) # figs/docs/x -> ../docs/x
    }
    if (!file.exists(src)) {
        missing <- c(missing, src)
        next
    }
    if (file.exists(dest) &&
        unname(tools::md5sum(dest)) == unname(tools::md5sum(src))) next
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    file.copy(src, dest, overwrite = TRUE)
    message("copied ", src, " -> slides/", dest)
}

if (length(missing)) {
    warning("figures not found (rebuild the website?):\n  ",
            paste(missing, collapse = "\n  "), call. = FALSE)
}
