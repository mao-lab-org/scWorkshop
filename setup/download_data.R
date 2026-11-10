# =============================================================================
# download_data.R — fetch the workshop data and pre-computed caches
#
# Run from the repository root:
#
#     source("setup/download_data.R")
#
# Downloads afternoonSession.zip (~2.7 GB) from Zenodo, checks its MD5,
# and places its contents in:
#
#     data/      afternoon_mvp.rds (query), reference_gao2026.rds (reference)
#     results/   pre-computed caches for Modules 5-7 (fallbacks for slow steps)
# =============================================================================

options(timeout = 7200)

zip_url  <- "https://zenodo.org/records/20017845/files/afternoonSession.zip?download=1"
zip_md5  <- "51709d9370933856709eb84fc85facc4"
zip_dest <- file.path("downloads", "afternoonSession.zip")

if (!file.exists("setup/download_data.R")) {
    stop("Run this script from the repository root (the folder that ",
         "contains 'setup/'). Current directory: ", getwd())
}
dir.create("downloads", showWarnings = FALSE)
dir.create("data",      showWarnings = FALSE)
dir.create("results",   showWarnings = FALSE)

## ---- 1. Download (skip if a verified copy already exists) -----------------
md5_ok <- function(f) file.exists(f) && unname(tools::md5sum(f)) == zip_md5

if (md5_ok(zip_dest)) {
    message("Verified ", zip_dest, " already present; skipping download.")
} else {
    message("Downloading afternoonSession.zip (~2.7 GB) ...")
    status <- utils::download.file(zip_url, zip_dest, mode = "wb",
                                   method = "libcurl")
    if (status != 0 || !md5_ok(zip_dest)) {
        stop("Download failed or MD5 mismatch. Delete ", zip_dest,
             " and re-run, or download it manually from\n  ", zip_url)
    }
    message("Download complete; MD5 verified.")
}

## ---- 2. Unzip to a staging folder -----------------------------------------
staging <- file.path("downloads", "unzipped")
unlink(staging, recursive = TRUE)
dir.create(staging)

ok <- tryCatch({
    utils::unzip(zip_dest, exdir = staging)
    TRUE
}, warning = function(w) FALSE, error = function(e) FALSE)
if (!ok) {
    # R's internal unzip can choke on very large members; fall back to the
    # system tar (bsdtar ships with Windows 10 / Server 2019 and later).
    message("R unzip failed; trying system tar ...")
    if (system2("tar", c("-xf", shQuote(zip_dest), "-C", shQuote(staging))) != 0)
        stop("Could not extract ", zip_dest)
}

## ---- 3. Move files into data/ and results/ --------------------------------
move_tree <- function(from, to) {
    files <- list.files(from, recursive = TRUE, all.files = FALSE)
    files <- files[!grepl("(^|/)\\.DS_Store$", files)]
    for (f in files) {
        dest <- file.path(to, f)
        dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
        file.copy(file.path(from, f), dest, overwrite = TRUE)
    }
    length(files)
}
root <- file.path(staging, "afternoonSession")
n_data <- move_tree(file.path(root, "add_to_data_folder"),    "data")
n_res  <- move_tree(file.path(root, "add_to_results_folder"), "results")
unlink(staging, recursive = TRUE)
message("Placed ", n_data, " files in data/ and ", n_res, " files in results/.")

## ---- 4. Check -------------------------------------------------------------
required <- c("data/afternoon_mvp.rds", "data/reference_gao2026.rds")
missing  <- required[!file.exists(required)]
if (length(missing)) stop("Missing after extraction: ", paste(missing, collapse = ", "))
message("Data ready. The zip in downloads/ can be deleted to save space.")
