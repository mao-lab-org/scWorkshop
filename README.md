# Modelling continuous cell states using scRNA-seq data

BiocAsia 2026 workshop (3 h). It is adapted from the afternoon session of the
Phipson Lab [single-cell workshop](https://phipsonlab.github.io/single_cell_workshop/).

**Website:** <https://mao-lab-org.github.io/scWorkshop/>, with the rendered
Introduction and modules.

| Module | Topic | Packages |
|---|---|---|
| – | Introduction: the data and the biological question | Seurat |
| 1 | Continuous phenotyping with Φ-Space | PhiSpace |
| 2 | Pseudotime trajectory analysis | slingshot, destiny |
| 3 | Cell-specific co-expression networks | NeighbourNet |

Data: snRNA-seq of the human heart at foetal, young and adult stages
(Sim et al. 2021, *Circulation*), with the Gao et al. 2026 left-ventricle
atlas as the Φ-Space reference.

## Setup

From the repository root in R 4.6 (Bioconductor 3.23):

```r
source("setup/install_packages.R")   # R packages
source("setup/download_data.R")      # data + caches from Zenodo (~2.7 GB)
source("setup/check_setup.R")        # verify
```

To set up the workshop VM, follow [setup/VM_SETUP.md](setup/VM_SETUP.md).

## Updating the website

The modules need the workshop data, so the site is built locally and only
published by GitHub Actions:

```bash
Rscript setup/build_site.R    # renders the home page and modules into docs/ (~1.5 min)
git add docs && git commit -m "Rebuild site" && git push
```

Pushing changes to `docs/` triggers `.github/workflows/pages.yml`, which
publishes the folder to GitHub Pages.
