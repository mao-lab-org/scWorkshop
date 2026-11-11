# =============================================================================
# nnet_viz.R — tidy tables and an interactive view for NeighbourNet networks
#
#   tabs <- nnet_tables(seu, i = 1)          # nodes + edges as data frames
#   nnet_vis(tabs)                           # interactive network (visNetwork)
#
# nnet_tables() calls NeighbourNet::visualise.network() and reads the network
# out of the plot it builds, so the tables (and the interactive view) always
# contain exactly the nodes, edges, TF modules and layout of the static plot.
# Run NeighbourNet::prepare.visualise() first, as for visualise.network().
#
# Prototype for the BiocAsia 2026 workshop (Module 3).
# =============================================================================

# TF-module colours: same palette as visualise.network() (Set1; grey = none).
.nnet_module_cols <- c("#BDBDBD", RColorBrewer::brewer.pal(9, "Set1"))

#' Nodes and edges of a NeighbourNet (meta-)network as data frames
#'
#' @param seu Seurat object after run.nn.reg(), build.meta.network() and
#'   prepare.visualise().
#' @param i Meta-network index (meta.network = TRUE) or cell index.
#' @param meta.network Plot a meta-network (TRUE) or a cell-specific network.
#' @param cutoff Edge confidence cutoff (0-1; higher keeps fewer edges).
#'   Default: the mean over targets of their strongest edge's confidence,
#'   as in the workshop vignette.
#' @param ... Passed to NeighbourNet::visualise.network().
#' @return list(nodes, edges, info)
nnet_tables <- function(seu, i, meta.network = TRUE, cutoff = NULL, ...) {
    mod <- Seurat::Misc(seu, "NNet.mod")
    vs  <- Seurat::Misc(seu, "NNet.visual.setting")
    if (is.null(vs)) stop("Run NeighbourNet::prepare.visualise() first.")

    # Edge confidence matrix (targets x TFs). NeighbourNet stores it as
    # "p.val", but higher values mean stronger evidence.
    conf <- if (meta.network) mod$meta.network$p.val[, , i] else mod$p.val[, , i]
    if (is.null(cutoff)) cutoff <- mean(apply(conf, 1, max), na.rm = TRUE)

    p <- suppressWarnings(NeighbourNet::visualise.network(
        seu, i = i, meta.network = meta.network, cutoff = cutoff, ...))

    ## ---- nodes ----
    nd <- as.data.frame(p$data)[, c("name", "x", "y", "type", "cluster")]
    # Pie glyphs (scatterpie, long format) hold each node's weight split by TF
    # module. Their group ids are not in node order, so match on position.
    pie <- as.data.frame(p$layers[[2]]$data)
    key <- function(x, y) paste(round(x, 6), round(y, 6))
    shares <- tapply(pie$value, list(key(pie$x, pie$y), as.character(pie$type)), sum)
    shares[is.na(shares)] <- 0
    shares <- shares[key(nd$x, nd$y), , drop = FALSE]
    if (anyNA(rownames(shares))) stop("Could not match pie glyphs to nodes.")
    mod_cols <- setdiff(colnames(shares), "N")      # V1..Vk = TF modules
    # strongest edge confidence over ALL partners, including genes not drawn
    nd$max_conf <- 1 - shares[, "N"]

    roles <- if (identical(vs$as.g2, "responses")) c("TF", "target") else c("target", "TF")
    nd$role <- c(roles, "pathway", "receptor", "spacer")[nd$type]
    nd$gene <- sub("^g[0-9]\\.", "", nd$name)
    nd$module <- ifelse(
        nd$role == "TF", nd$cluster - 1L,
        ifelse(nd$max_conf > 0 & nd$role %in% c("target", "receptor"),
               as.integer(sub("V", "", mod_cols[max.col(shares[, mod_cols, drop = FALSE],
                                                          ties.method = "first")])),
               NA_integer_))
    nd <- nd[nd$role != "spacer", ]

    ## ---- edges ----
    g  <- tidygraph::as.igraph(attr(p$data, "graph"))
    ed <- igraph::as_data_frame(g, "edges")
    ed <- ed[ed$evidence >= 2, c("from", "to", "weight", "cluster", "evidence")]
    ed$prior <- c("none", "activation", "inhibition")[ed$evidence - 1]
    ed$module <- ifelse(ed$cluster > 1, ed$cluster - 1L, NA_integer_)
    gene_of <- setNames(nd$gene, nd$name)
    role_of <- setNames(nd$role, nd$name)
    ed$kind <- ifelse(role_of[ed$from] == "TF" & role_of[ed$to] == "target" |
                      role_of[ed$from] == "target" & role_of[ed$to] == "TF",
                      "co-expression", "signalling path")
    # confidence for TF-target edges
    tf  <- ifelse(role_of[ed$from] == "TF", gene_of[ed$from], gene_of[ed$to])
    tgt <- ifelse(role_of[ed$from] == "TF", gene_of[ed$to],   gene_of[ed$from])
    ed$confidence <- NA_real_
    ok <- ed$kind == "co-expression" & tgt %in% rownames(conf) & tf %in% colnames(conf)
    ed$confidence[ok] <- conf[cbind(tgt[ok], tf[ok])]
    ed <- ed[order(-ed$weight), c("from", "to", "kind", "weight", "confidence",
                                  "prior", "module")]
    rownames(ed) <- NULL

    nd$degree <- vapply(nd$name, function(n) sum(ed$from == n | ed$to == n), integer(1))
    nd <- nd[, c("name", "gene", "role", "module", "max_conf", "degree", "x", "y")]
    rownames(nd) <- NULL

    list(nodes = nd, edges = ed,
         info = list(i = i, meta.network = meta.network, cutoff = cutoff,
                     n_modules = length(mod_cols)))
}

#' Interactive view of nnet_tables() output
#'
#' Hover a gene or edge for details; click a gene (or pick it in the menu)
#' to highlight its partners; drag to pan, scroll to zoom.
#'
#' @param tabs Output of nnet_tables().
#' @param show_isolated Keep genes with no edge above the cutoff (greyed out).
#' @param title Plot title; default says which network is shown.
#' @param height Widget height. Default: the window height minus room for
#'   the legend in a browser or the RStudio Viewer, and 550 px in knitted
#'   documents and RStudio's inline chunk output.
nnet_vis <- function(tabs, show_isolated = TRUE, title = NULL, height = NULL) {
    nd <- tabs$nodes; ed <- tabs$edges; info <- tabs$info
    if (!show_isolated) nd <- nd[nd$degree > 0, ]

    col_of <- function(m) ifelse(is.na(m), .nnet_module_cols[1],
                                 .nnet_module_cols[pmin(m + 1L, length(.nnet_module_cols))])
    shape_of <- c(TF = "diamond", target = "dot", receptor = "triangle",
                  pathway = "square")

    # partners listed in each gene's tooltip
    partners <- vapply(nd$name, function(n) {
        e <- ed[ed$from == n | ed$to == n, ]
        if (!nrow(e)) return("<i>no edge above the cutoff</i>")
        other <- ifelse(e$from == n, e$to, e$from)
        paste0(sub("^g[0-9]\\.", "", other), " (", sprintf("%.2f", e$weight), ")",
               collapse = ", ")
    }, character(1))
    dup <- nd$gene %in% nd$gene[duplicated(nd$gene)]

    isolated <- nd$degree == 0
    nodes <- data.frame(
        id    = nd$name,
        label = nd$gene,
        group = nd$role,
        shape = unname(shape_of[nd$role]),
        size  = ifelse(nd$role == "pathway" | isolated, 9, 14 + 16 * nd$max_conf),
        x     = nd$x * 320,
        y     = -nd$y * 320,                 # vis.js y axis points down
        title = paste0(
            "<b>", nd$gene, "</b> &middot; ", nd$role,
            ifelse(nd$role == "TF", paste0(" &middot; TF module ", nd$module), ""),
            ifelse(dup, "<br><i>also shown in its other role</i>", ""),
            "<br>strongest edge confidence (any partner): ", sprintf("%.2f", nd$max_conf),
            ifelse(nd$degree == 0 & nd$max_conf > info$cutoff,
                   "<br><i>its strongest partner is not among the genes drawn</i>", ""),
            "<br>partners shown: ", partners),
        stringsAsFactors = FALSE
    )
    # Colour means TF module only: TFs are filled with their module colour;
    # targets / receptors are neutral, so a target's colour never competes
    # with the colours of the edges reaching it.
    nodes$color.background <- ifelse(isolated, "#F2F2F2",
                                     ifelse(nd$role == "TF", col_of(nd$module), "#FFFFFF"))
    nodes$color.border     <- ifelse(isolated, "#BDBDBD", "#333333")
    nodes$font.color       <- ifelse(isolated, "#9E9E9E", "#222222")
    nodes$borderWidth      <- ifelse(isolated, 1, 2)

    edges <- data.frame(
        from   = ed$from,
        to     = ed$to,
        width  = 1 + 7 * ed$weight,
        color  = col_of(ed$module),
        title  = paste0(
            "<b>", sub("^g[0-9]\\.", "", ed$from), " &ndash; ",
            sub("^g[0-9]\\.", "", ed$to), "</b> (", ed$kind, ")",
            "<br>edge weight: ", sprintf("%.2f", ed$weight),
            ifelse(is.na(ed$confidence), "",
                   paste0("<br>confidence: ", sprintf("%.2f", ed$confidence))),
            "<br>prior knowledge: ",
            c(none = "none (undirected, co-expression only)", activation = "activation",
              inhibition = "inhibition")[ed$prior]),
        stringsAsFactors = FALSE
    )
    # As in NeighbourNet's plots: edges without prior knowledge are
    # undirected and dashed (dash length scales with width, or thick edges
    # look solid); prior-supported edges are solid with an arrow or a bar.
    edges$dashes <- lapply(seq_len(nrow(ed)), function(k) {
        if (ed$prior[k] != "none") return(FALSE)
        c(max(6, 2.5 * edges$width[k]), max(5, 2 * edges$width[k]))
    })
    edges$arrows.to.enabled <- ed$prior != "none"
    edges$arrows.to.type    <- ifelse(ed$prior == "inhibition", "bar", "arrow")

    if (is.null(title)) {
        title <- if (info$meta.network) paste("Meta-network", info$i)
                 else paste("Cell-specific network, cell", info$i)
    }
    sub <- sprintf(paste0("Edges with confidence > %.2f. Hover for details; ",
                          "click a gene to highlight its partners."), info$cutoff)

    mods <- sort(unique(stats::na.omit(nd$module[nd$role == "TF"])))
    legend <- .nnet_legend(mods, col_of, receptors = any(nd$role == "receptor"))

    w <- visNetwork::visNetwork(nodes, edges, main = title, submain = sub,
                           height = height, width = "100%") |>
        visNetwork::visPhysics(enabled = FALSE) |>
        visNetwork::visEdges(smooth = FALSE, selectionWidth = 2,
                             hoverWidth = 1) |>
        visNetwork::visNodes(font = list(size = 18, face = "arial")) |>
        visNetwork::visOptions(
            highlightNearest = list(enabled = TRUE, degree = 1, hover = FALSE,
                                    algorithm = "hierarchical"),
            nodesIdSelection = list(enabled = TRUE, main = "Select a gene",
                                    values = nd$name[order(nd$gene)]),
            selectedBy = list(variable = "group", main = "Select a role")
        ) |>
        visNetwork::visInteraction(hover = TRUE, tooltipDelay = 80,
                                   navigationButtons = TRUE, dragNodes = TRUE)
    # Height by context (when `height` is NULL): browser and RStudio Viewer
    # get the window minus room for the legend (not htmlwidgets' fill mode,
    # which pushes the legend off screen); knitr contexts (knitted HTML and
    # RStudio's inline chunk output) get a fixed height, since a
    # window-relative one would follow the inline output frame.
    window_height <- "calc(100vh - 200px)"
    w$sizingPolicy$browser$fill <- FALSE
    w$sizingPolicy$viewer$fill  <- FALSE
    w$sizingPolicy$browser$defaultHeight <- window_height
    w$sizingPolicy$viewer$defaultHeight  <- window_height
    w$sizingPolicy$knitr$figure <- FALSE
    w$sizingPolicy$knitr$defaultHeight <- "550px"
    htmlwidgets::appendContent(w, legend)
}

# Legend as plain HTML below the widget. visLegend() draws on a canvas that
# is zoomed out to fit all entries, which shrank its text to ~8px; HTML text
# stays at a fixed, readable size.
.nnet_legend <- function(mods, col_of, receptors = FALSE, font_px = 15) {
    svg <- function(body, w = 20) {
        sprintf(paste0('<svg width="%d" height="20" viewBox="0 0 %d 20" ',
                       'style="vertical-align:middle;">%s</svg>'), w, w, body)
    }
    node_svg <- function(shape, fill, stroke = "#333333") {
        body <- switch(shape,
            diamond  = '<polygon points="10,2 18,10 10,18 2,10"',
            dot      = '<circle cx="10" cy="10" r="7"',
            triangle = '<polygon points="10,2 18,17 2,17"')
        svg(sprintf('%s fill="%s" stroke="%s" stroke-width="1.5"/>', body, fill, stroke))
    }
    edge_svg <- function(end = c("none", "arrow", "bar"), width = 3, dashed = FALSE) {
        end <- match.arg(end)
        line <- sprintf('<line x1="2" y1="10" x2="34" y2="10" stroke="#555555" stroke-width="%s"%s/>',
                        width, if (dashed) ' stroke-dasharray="5,4"' else "")
        tip <- switch(end,
            none  = "",
            arrow = '<polygon points="38,10 29,5 29,15" fill="#555555"/>',
            bar   = '<line x1="37" y1="3" x2="37" y2="17" stroke="#555555" stroke-width="3"/>')
        svg(paste0(line, tip), w = 40)
    }
    item <- function(icon, label) {
        sprintf(paste0('<span style="display:inline-block;margin:0 16px 6px 0;',
                       'white-space:nowrap;">%s<span style="vertical-align:middle;',
                       'margin-left:6px;">%s</span></span>'), icon, label)
    }
    row <- function(title, items) {
        # plain text flow (inline-block items), not flexbox: wraps the same
        # way in RStudio's viewer, knitted HTML and standalone pages
        sprintf(paste0('<div style="display:block;width:100%%;">',
                       '<span style="display:inline-block;font-weight:bold;',
                       'margin:0 12px 6px 0;vertical-align:middle;">%s</span>%s</div>'),
                title, paste(items, collapse = " "))
    }
    genes <- c(
        item(node_svg("diamond", "#FFFFFF"), "TF"),
        item(node_svg("dot", "#FFFFFF"), "target gene"),
        if (receptors) item(node_svg("triangle", "#FFFFFF"), "receptor"),
        vapply(mods, function(m) item(node_svg("diamond", col_of(m)),
                                      paste("TF module", m)), character(1)),
        item(node_svg("dot", "#F2F2F2", "#BDBDBD"), "no edge above cutoff")
    )
    edges <- c(
        item(edge_svg("none", dashed = TRUE),
             "co-expression only (undirected, not in prior knowledge)"),
        item(edge_svg("arrow"), "+ prior knowledge: activation"),
        item(edge_svg("bar"), "+ prior knowledge: inhibition"),
        item("", "(width = weight)")
    )
    htmltools::HTML(sprintf(
        paste0('<div style="font-family:Arial,Helvetica,sans-serif;font-size:%dpx;',
               'color:#222222;padding:8px 4px 4px;">%s%s</div>'),
        font_px, row("Genes", genes), row("Edges", edges)))
}
