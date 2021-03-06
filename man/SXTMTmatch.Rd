% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tools.R
\name{SXTMTmatch}
\alias{SXTMTmatch}
\title{SXTMTmatch}
\usage{
SXTMTmatch(data1, data2, mz.tolerance = 25, rt.tolerance = 180)
}
\arguments{
\item{data1}{First data for matching, first column must be mz
and seconod column must be rt.}

\item{data2}{Second data for matching, first column must be mz
and seconod column must be rt.}

\item{mz.tolerance}{mz tolerance for ms1 and ms2 data matching.}

\item{rt.tolerance}{RT tolerance for ms1 and ms2 data matching.}
}
\value{
Return a result which give the matching result of data1 and database.
}
\description{
Match two data according to mz and RT.
}
\details{
HeatMap <- function(MetFlowData,
                    log.scale = FALSE,
                    color = c("palegreen",
                              "firebrick1",
                              "royalblue",
                              "yellow",
                              "black",
                              "cyan",
                              "gray48"),
                    variable = "all",
                    Group = c("control", "case"),
                    scale.method = "auto",
                    show_rownames = FALSE,
                    show_colnames = FALSE,
                    path = ".",
                    width = 7,
                    height = 7,
                    border_color = NA,
                    fontsize_row = 10,
                    cluster_rows = TRUE,
                    cluster_cols = TRUE,
                    clustering_method = "ward.D",
                    ...) {
  if (path != ".") {
    dir.create(path)
  }

subject <- MetFlowData@subject
  tags <- MetFlowData@tags
  subject.info <- MetFlowData@subject.info
  group <- subject.info[, "group"]

idx <- which(group %in% Group)
  subject.info <- subject.info[idx, ]
  subject <- subject[, idx]
  group <- subject.info[, "group"]
  ## data organization
  if (variable == "all") {
    data <- t(subject)
  } else{
    if (all(colnames(tags) != "is.marker")) {
      stop("Please select marker first.")
    }
    is.marker <- tags[, "is.marker"]
    var.index <- which(is.marker == "yes")
    data <- t(subject[var.index, ])
  }

##log transformation
  if (log.scale == FALSE) {
    data <- data
  }

if (log.scale == "e") {
    data <- log(data + 1)
  }

if (log.scale != FALSE & log.scale != "e") {
    data <- log(data + 1, as.numeric(log.scale))
  }

data1 <- SXTscale(data, method = scale.method)
  data1.range <- abs(range(data1))
  dif <- data1.range[1] - data1.range[2]
  if (dif < 0) {
    data1[data1 > data1.range[1]] <- data1.range[1]
  }
  if (dif > 0) {
    data1[data1 < -1 * data1.range[2]] <- -1 * data1.range[2]
  }

annotation_col <- data.frame(Group = factor(c(group)))

rownames(annotation_col) <- rownames(data)

# Specify colors
  ann_col <- NULL
  for (i in seq_along(Group)) {
    ann_col[i] <- color[i]
  }

ann_colors = list(Group = ann_col)
  names(ann_colors[[1]]) <- Group

pdf(file.path(path, "heatmap.pdf"),
      width = width,
      height = height)
  par(mar = c(5,5,4,2))
  pheatmap::pheatmap(
    t(data1),
    color = colorRampPalette(c("green", "black", "red"))(1000),
    scale = "none",
    show_rownames = show_rownames,
    show_colnames = show_colnames,
    border_color = border_color,
    annotation_col = annotation_col,
    annotation_colors = ann_colors,
    fontsize_row = fontsize_row,
    cluster_rows = cluster_rows,
    cluster_cols = cluster_cols,
    clustering_method = clustering_method,
    ...
  )
  dev.off()
}
}
\author{
Xiaotao Shen
\email{shenxt@sioc.ac.cn}
}
