# =============================================================================
# install_packages.R — install every R package the workshop needs
#
# Run once on the workshop VM (or your own machine) from the repository root:
#
#     source("setup/install_packages.R")
#
# Target: R 4.6.x + Bioconductor 3.23. On Windows and macOS all CRAN and
# Bioconductor packages install as pre-built binaries. PhiSpace and
# NeighbourNet are pure-R packages installed from GitHub, so no compiler
# (Rtools / Xcode) is required.
# =============================================================================

options(
    repos   = c(CRAN = "https://cloud.r-project.org"),
    timeout = 3600,             # large binaries on slow links
    Ncpus   = max(1L, parallel::detectCores() - 1L)
)

## ---- 0. R version ----------------------------------------------------------
bioc_version <- "3.23"
if (getRversion() < "4.6.0") {
    stop("R ", getRversion(), " detected. This workshop needs R >= 4.6.0 ",
         "(Bioconductor ", bioc_version, "). Install R 4.6.x from ",
         "https://cran.r-project.org and re-run this script.")
}
message("R ", getRversion(), " on ", R.version$platform)

## ---- 1. Installers ----------------------------------------------------------
for (p in c("BiocManager", "remotes")) {
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
BiocManager::install(version = bioc_version, ask = FALSE, update = FALSE)

## ---- 2. CRAN + Bioconductor packages ---------------------------------------
cran_pkgs <- c(
    # general
    "rmarkdown", "knitr", "ggplot2", "dplyr", "tidyr", "tibble",
    "patchwork", "RColorBrewer", "Matrix", "igraph",
    # Seurat (NeighbourNet works on Seurat objects)
    "Seurat", "SeuratObject",
    # PhiSpace imports from CRAN
    "kerndwd", "umap", "FNN", "ggpubr", "irlba", "plyr", "magrittr", "withr",
    # NeighbourNet imports from CRAN
    "RANN", "progress", "RSpectra", "ggraph", "reshape2", "scatterpie"
)
bioc_pkgs <- c(
    "SingleCellExperiment", "SummarizedExperiment", "SpatialExperiment",
    "S4Vectors", "BiocParallel",
    "scuttle", "scran", "scater",           # normalisation, SNN graph, UMAP
    "ComplexHeatmap",                       # Module 5 heatmap
    "slingshot",                            # Module 6 principal curves
    "destiny",                              # Module 6 diffusion pseudotime
    # Optional ("Suggests") dependencies that slingshot / scater / scran
    # load at run time; not pulled in automatically by install().
    "DelayedMatrixStats", "mclust"
)

needed <- setdiff(c(cran_pkgs, bioc_pkgs), rownames(installed.packages()))
if (length(needed)) {
    message("Installing ", length(needed), " CRAN/Bioconductor packages: ",
            paste(needed, collapse = ", "))
    BiocManager::install(needed, ask = FALSE, update = FALSE)
} else {
    message("All CRAN/Bioconductor packages already installed.")
}

## ---- 3. GitHub packages (pinned commits) -----------------------------------
# Pinned so every participant VM gets exactly the version we dry-ran.
github_pkgs <- c(
    PhiSpace     = "mao-lab-org/PhiSpace@684adb8ae077922f2406cbee6a43ffe17908e3a2",
    NeighbourNet = "meiosis97/NeighbourNet@6a8de81765fc27822b4fc3b19e870fed2083a8e9"
)
installed_sha <- function(pkg) {
    # Read DESCRIPTION without loading the namespace (a loaded old version
    # would otherwise shadow the freshly installed one in this session).
    if (!nzchar(system.file(package = pkg))) return(NA_character_)
    d <- utils::packageDescription(pkg)
    if (is.null(d$RemoteSha)) NA_character_ else d$RemoteSha
}
for (pkg in names(github_pkgs)) {
    want <- sub(".*@", "", github_pkgs[[pkg]])
    if (identical(installed_sha(pkg), want)) {
        message(pkg, " already at pinned commit ", substr(want, 1, 7))
        next
    }
    message("Installing ", pkg, " from GitHub (", github_pkgs[[pkg]], ")")
    remotes::install_github(
        github_pkgs[[pkg]],
        dependencies    = NA,    # Depends/Imports only, not Suggests

        upgrade         = "never",
        build_vignettes = FALSE,
        force           = TRUE
    )
}

## ---- 4. Verify ------------------------------------------------------------
all_pkgs <- c(cran_pkgs, bioc_pkgs, names(github_pkgs))
ok <- vapply(all_pkgs, requireNamespace, logical(1), quietly = TRUE)
if (all(ok)) {
    message("\nAll ", length(all_pkgs), " packages installed and loadable.")
} else {
    stop("These packages failed to install or load: ",
         paste(all_pkgs[!ok], collapse = ", "),
         "\nRe-run this script; if it fails again, install them one by one ",
         "with BiocManager::install() to see the error.")
}
