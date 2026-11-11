# =============================================================================
# check_setup.R — confirm the environment is ready for the workshop
#
# Run from the repository root:
#
#     source("setup/check_setup.R")
#
# Checks R / package versions, data files, and runs a ~1 minute smoke test
# that touches every key function used in Modules 1-3.
# =============================================================================

if (!file.exists("setup/check_setup.R")) {
    stop("Run this script from the repository root. Current directory: ", getwd())
}

cat("=== Workshop setup check ===\n\n")
cat(sprintf("%-14s %s\n", "R:", R.version.string))
cat(sprintf("%-14s %s %s\n", "OS:", Sys.info()[["sysname"]], Sys.info()[["release"]]))
cat(sprintf("%-14s %s\n", "Bioconductor:", as.character(BiocManager::version())))
cat(sprintf("%-14s %d\n", "CPU cores:", parallel::detectCores()))

## ---- packages --------------------------------------------------------------
pkgs <- c("Seurat", "SeuratObject", "SingleCellExperiment", "scran", "scuttle", "scater",
          "ComplexHeatmap", "slingshot", "destiny", "PhiSpace", "NeighbourNet",
          "DelayedMatrixStats", "mclust", "uwot", "visNetwork", "ggiraph",
          "ggplot2", "dplyr", "tidyr", "tibble", "patchwork", "RColorBrewer",
          "rmarkdown", "knitr")
cat("\nPackages:\n")
pkg_ok <- vapply(pkgs, function(p) {
    ok <- requireNamespace(p, quietly = TRUE)
    v  <- if (ok) as.character(utils::packageVersion(p)) else "MISSING"
    sha <- if (ok) utils::packageDescription(p)$RemoteSha else NULL
    cat(sprintf("  %-22s %s%s\n", p, v,
                if (!is.null(sha) && nchar(sha) == 40)
                    paste0(" (", substr(sha, 1, 7), ")") else ""))
    ok
}, logical(1))

## ---- data ------------------------------------------------------------------
files <- c(
    "data/afternoon_mvp.rds", "data/reference_gao2026.rds",
    "results/05_phispace_query.rds", "results/06_cm_pseudotime.rds",
    "results/07_seu_nnet_10targets.rds"
)
cat("\nData files:\n")
file_ok <- vapply(files, function(f) {
    ok <- file.exists(f)
    cat(sprintf("  %-38s %s\n", f,
                if (ok) sprintf("%.0f MB", file.size(f) / 1e6) else "NOT FOUND"))
    ok
}, logical(1))

if (!all(pkg_ok) || !all(file_ok[1:2])) {
    cat("\nSetup INCOMPLETE. Run setup/install_packages.R and/or",
        "setup/download_data.R, then re-run this check.\n")
    stop("Setup incomplete.", call. = FALSE)
}

## ---- smoke test ------------------------------------------------------------
cat("\nSmoke test (small subsets) ...\n")
t0 <- Sys.time()
suppressPackageStartupMessages({
    library(SingleCellExperiment)
    library(PhiSpace)
})
set.seed(1)

seu <- readRDS("data/afternoon_mvp.rds")
ref <- readRDS("data/reference_gao2026.rds")
query <- Seurat::as.SingleCellExperiment(seu[, sample(ncol(seu), 500)])
query <- scranTransf(query)
common <- intersect(rownames(ref), rownames(query))
ref <- ref[common, ]
query <- zeroFeatQC(query[common, ])
query <- PhiSpace(reference = ref, query = query,
                  phenotypes = "age_group", refAssay = "logcounts",
                  regMethod = "PLS", center = TRUE, scale = FALSE)
sc <- reducedDim(query, "PhiSpace")
cat("  PhiSpace      OK  (", nrow(sc), "cells x", ncol(sc), "scores )\n")

lab <- getLabels(sc)
cat("  getLabels     OK  (", length(unique(lab)), "labels )\n")

dm <- destiny::DiffusionMap(as.matrix(sc), n_eigs = 3, verbose = FALSE)
dpt <- destiny::DPT(dm, tips = which.max(sc[, "fetal"]))
cat("  destiny DPT   OK\n")

cl <- kmeans(sc, 3)$cluster
sds <- slingshot::slingshot(sc, clusterLabels = cl, dist.method = "simple")
cat("  slingshot     OK  (", length(slingshot::slingLineages(sds)), "lineage(s) )\n")

seu_small <- Seurat::as.Seurat(query, counts = "counts", data = "logcounts")
genes <- NeighbourNet::select.gene(seu_small, min.cells = 10)
cat("  NeighbourNet  OK  (", length(genes$tfs), "TFs,",
    length(genes$targets), "targets pass filter )\n")

cat(sprintf("\nAll checks passed in %.0f s. Ready for the workshop.\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
