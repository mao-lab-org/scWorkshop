# =============================================================================
# dry_run.R — render Modules 1-3 end to end and report timings
#
# From the repository root:
#
#   Rscript setup/dry_run.R          # use the caches in results/ (fast;
#                                    # what participants will experience)
#   Rscript setup/dry_run.R --fresh  # ignore caches and recompute every step
#                                    # into results_fresh/ (slow; tests the
#                                    # full compute path on this machine)
#
# Rendered HTML goes to dry_run/. A timing table is printed at the end.
# =============================================================================

if (!file.exists("setup/dry_run.R")) {
    stop("Run this script from the repository root. Current directory: ", getwd())
}

fresh   <- "--fresh" %in% commandArgs(trailingOnly = TRUE)
# Create before normalizing: normalizePath() leaves a non-existent path
# relative, and the vignettes (rendered from vignettes/) would then resolve
# it against the wrong directory.
res_dir <- if (fresh) "results_fresh" else "results"
dir.create(res_dir, showWarnings = FALSE)
dir.create("dry_run", showWarnings = FALSE)
res_dir <- normalizePath(res_dir)
out_dir <- normalizePath("dry_run")
Sys.setenv(SCW_RESULTS = res_dir)

modules <- c("vignettes/01_phispace_annotation.Rmd",
             "vignettes/02_pseudotime.Rmd",
             "vignettes/03_nnet.Rmd")

message("Mode: ", if (fresh) "FRESH (recompute everything)" else "cached",
        "\nResults dir: ", res_dir)

timings <- data.frame(module = basename(modules), seconds = NA_real_,
                      status = NA_character_)
for (i in seq_along(modules)) {
    message("\n==== Rendering ", modules[i], " ====")
    t0 <- Sys.time()
    st <- tryCatch({
        rmarkdown::render(modules[i], output_dir = out_dir, quiet = TRUE,
                          envir = new.env())
        "OK"
    }, error = function(e) paste("ERROR:", conditionMessage(e)))
    timings$seconds[i] <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
    timings$status[i]  <- st
    message(st, " (", timings$seconds[i], " s)")
    if (st != "OK") break   # later modules depend on earlier ones
}

cat("\n=== Dry-run summary ===\n")
print(timings, row.names = FALSE)
cat("HTML output in", out_dir, "\n")
if (any(timings$status != "OK", na.rm = TRUE) || anyNA(timings$status)) quit(status = 1)
