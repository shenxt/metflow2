#' @title filterPeak
#' @description Filter peaks.
#' @author Xiaotao Shen
#' \email{shenxt1990@@163.com}
#' @param object A metflowClass object.
#' @param min.fraction.qc Peaks minimum fraction in QC samples.
#' @param min.fraction Peaks minimun fraction in subject samples.
#' @param min.subject.qc.ratio Peak intensity ratio in subject and blank samples.
#' @param dl.qc.r2.cutoff R2 cutoff for dilution QC.
#' @import tidyverse
#' @import tibble
#' @return A new metflowClass object.
#' @export

setGeneric(
  name = "filterPeak",
  def = function(object,
                 min.fraction.qc = 0.8,
                 min.fraction = 0.8,
                 min.subject.qc.ratio = 2,
                 dl.qc.r2.cutoff = 0.7) {
    if (class(object) != "metflowClass") {
      stop("Only the metflowClass is supported!\n")
    }
    
    ms1_data <- object@ms1.data
    
    if (length(ms1_data) > 1) {
      stop("Please algin your peak tables first!\n")
    }
    ms1_data <- ms1_data[[1]]
    # sample <- ms1_data[,match(sample_info$sample.name, colnames(ms1_data))]
    # tags <- ms1_data[,-match(sample_info$sample.name, colnames(ms1_data))]
    sample_info <- object@sample.info
    object@process.info$filterPeaks <- list()
    
    cat(paste(rep("-", 20), collapse = ""), "\n")
    cat("Removing peaks according to NA in QC samples...\n")
    #remove peaks according to NA in QC samples
    if ("QC" %in% sample_info$class) {
      qc_sample <-
        `==`(sample_info$class, "QC") %>%
        which(.) %>%
        `[`(sample_info$sample.name, .) %>%
        match(., colnames(ms1_data)) %>%
        `[`(ms1_data, , .)
      
      na.fraction <- apply(qc_sample, 1, function(x) {
        sum(!is.na(x)) / ncol(qc_sample)
      })
      
      remain.idx <- which(na.fraction > min.fraction.qc)
      if (length(remain.idx) == 0) {
        stop(paste("No peaks meet min.fraction.qc:", min.fraction.qc))
      }
      cat(length(remain.idx),
          "out of",
          nrow(ms1_data),
          "peaks are remained.\n")
      ms1_data <- ms1_data[remain.idx, , drop = FALSE]
      object@process.info$filterPeaks$min.fraction.qc <-
        min.fraction.qc
      rm(list = c("remain.idx"))
    }
    
    
    cat(paste(rep("-", 20), collapse = ""), "\n")
    cat("Removing peaks according to NA in subject samples...\n")
    
    ##remove peaks according to NA in subject samples
    subject_name <-
      which(sample_info$class == "Subject") %>%
      `[`(sample_info$sample.name, .)
    
    subject_data <- subject_name %>%
      match(., colnames(ms1_data)) %>%
      `[`(ms1_data, , .)
    
    subject_group <- subject_name %>%
      match(., sample_info$sample.name) %>%
      `[`(sample_info$group, .)
    
    na.fraction <-
      lapply(unique(subject_group), function(group) {
        temp_subject_data <-
          subject_data[, which(subject_group == group), drop = FALSE]
        apply(temp_subject_data, 1, function(x)
          sum(!is.na(x)) / ncol(temp_subject_data))
      })
    
    na.fraction <- do.call(cbind, na.fraction)
    remain.idx <- apply(na.fraction, 1, function(x) {
      any(x >  min.fraction)
    }) %>%
      which(.)
    
    if (length(remain.idx) == 0) {
      stop(paste("No peaks meet min.fraction:", min.fraction))
    }
    cat(length(remain.idx),
        "out of",
        nrow(ms1_data),
        "peaks are remained.\n")
    ms1_data <- ms1_data[remain.idx, , drop = FALSE]
    subject_data <-
      subject_data[remain.idx, , drop = FALSE]
    object@process.info$filterPeaks$min.fraction <-
      min.fraction
    rm(list = c(
      "remain.idx",
      "na.fraction",
      "subject_group",
      "subject_name"
    ))
    
    cat(paste(rep("-", 20), collapse = ""), "\n")
    cat("Removing peaks according to blank samples...\n")
    ##remove peaks according to blank
    if ("Blank" %in% sample_info$class) {
      blank_data <-
        `==`(sample_info$class, "Blank") %>%
        which(.) %>%
        `[`(sample_info$sample.name, .) %>%
        dplyr::select(.data = ms1_data, .)
      peak_mean_int_blank <-
        apply(blank_data, 1, function(x)
          mean(x, na.rm = TRUE))
      peak_mean_int_blank[is.na(peak_mean_int_blank)] <- 0
      
      peak_mean_int_subject <-
        apply(subject_data, 1, function(x)
          mean(x, na.rm = TRUE))
      peak_mean_int_subject[is.na(peak_mean_int_subject)] <-
        0
      
      ratio <- peak_mean_int_subject / peak_mean_int_blank
      ratio[is.na(ratio)] <- 0
      remain.idx <- which(ratio > min.subject.qc.ratio)
      if (length(remain.idx) == 0) {
        stop(paste(
          "No peaks meet min.subject.qc.ratio:",
          min.subject.qc.ratio
        ))
      }
      cat(length(remain.idx),
          "out of",
          nrow(ms1_data),
          "peaks are remained.\n")
      object@process.info$filterPeaks$min.subject.qc.ratio <-
        min.subject.qc.ratio
      ms1_data <- ms1_data[remain.idx, , drop = FALSE]
      rm(
        list = c(
          "blank_data",
          "subject_data",
          "peak_mean_int_subject",
          "peak_mean_int_blank",
          "ratio",
          "remain.idx"
        )
      )
    }
    
    cat(paste(rep("-", 20), collapse = ""), "\n")
    cat("Removing peaks according to QC dilution samples...\n")
    ###remove peaks according to dilution
    if ("QC.DL" %in% sample_info$class) {
      qc_dl_sample <-
        `==`(sample_info$class, "QC.DL") %>%
        which(.) %>%
        `[`(sample_info$sample.name, .) %>%
        match(., colnames(ms1_data)) %>%
        `[`(ms1_data, , .)
      qc_dl_sample <-
        qc_dl_sample[, order(colnames(qc_dl_sample))]
      cat("The QC_DL sample names are:",
          paste(colnames(qc_dl_sample), collapse = "; "),
          "\n")
      
      dl_name <-
        stringr::str_extract_all(string = colnames(qc_dl_sample),
                                 pattern = "DL[0-9]{1,2}") %>%
        unlist()
      
      qc_dl_sample <-
        lapply(sort(unique(dl_name)), function(x) {
          which(x == dl_name) %>%
            `[`(qc_dl_sample, , .)
        })
      
      qc_dl_sample <- lapply(qc_dl_sample, function(x) {
        temp <- apply(x, 1, function(x)
          mean(x, na.rm = TRUE))
        temp[is.na(temp)] <- 0
        temp
      })
      
      qc_dl_sample <- do.call(cbind, qc_dl_sample)
      colnames(qc_dl_sample) <- sort(unique(dl_name))
      qc_dl_sample <-
        as.data.frame(qc_dl_sample, stringsAsFactors = FALSE)
      dl_grade <-
        stringr::str_extract(string = sort(unique(dl_name)),
                             pattern = "[0-9]{1,2}") %>%
        as.numeric(.)
      ####construct linear regression
      remain.idx <- apply(qc_dl_sample, 1, function(y) {
        y <- as.numeric(y)
        temp.lm <- lm(y ~ dl_grade)
        (coefficients(temp.lm)[2] < 0 &
            summary(temp.lm)$r.squared > dl.qc.r2.cutoff)
      }) %>%
        which(.)
      
      if (length(remain.idx) == 0) {
        stop(paste("No peaks meet dl.qc.r2.cutoff:", dl.qc.r2.cutoff))
      }
      
      cat(length(remain.idx),
          "out of",
          nrow(ms1_data),
          "peaks are remained.\n")
      
      object@process.info$filterPeaks$dl.qc.r2.cutoff <-
        dl.qc.r2.cutoff
      ms1_data <- ms1_data[remain.idx, , drop = FALSE]
    }
    
    ms1_data <- list(ms1_data)
    object@ms1.data <- ms1_data
    cat("All is done.\n")
    invisible(object)
  }
)


#' @title filterSample
#' @description Filter samples.
#' @author Xiaotao Shen
#' \email{shenxt1990@@163.com}
#' @param object A metflowClass object.
#' @param min.fraction.peak Peaks minimun fraction in subject samples.
#' @return A new metflowClass object.
#' @export

setGeneric(
  name = "filterSample",
  def = function(object,
                 min.fraction.peak = 0.8) {
    # requireNamespace("ggplot2")
    # requireNamespace("tidyverse")
    # requireNamespace("magrittr")
    if (class(object) != "metflowClass") {
      stop("Only the metflowClass is supported!\n")
    }
    
    ms1_data <- object@ms1.data
    
    if (length(ms1_data) > 1) {
      stop("Please algin your peak tables first!\n")
    }
    ms1_data <- ms1_data[[1]]
    qc_data <- getData(object = object, slot = "QC")
    subject_data <-
      getData(object = object, slot = "Subject")
    subject_qc_data <- cbind(qc_data, subject_data)
    subject_qc_data <- tibble::as_tibble(subject_qc_data)
    class <-
      c(rep("QC", ncol(qc_data)), rep("Subject", ncol(subject_data)))
    
    na.fraction <- apply(subject_qc_data, 2, function(x) {
      sum(is.na(x) / nrow(subject_qc_data))
    })
    
    
    remove.idx.na.fraction <-
      which(na.fraction > 1 - min.fraction.peak)
    
    cat(
      "Samples with MV ratio larger than",
      min.fraction.peak,
      ":\n",
      paste(names(remove.idx.na.fraction), collapse = "; ")
    )
    cat("\n")
    
    # na.fraction <- sort(na.fraction)
    na.fraction <-
      data.frame(
        peak.name = names(na.fraction),
        index = 1:length(na.fraction),
        class = class,
        na.fraction,
        stringsAsFactors = FALSE
      )
    
    na.fraction <-
      left_join(na.fraction, object@sample.info[,c(1,2)], by = c("peak.name" = "sample.name"))
    
    plot <- ggplot(data = na.fraction) +
      geom_point(aes(
        x = injection.order,
        y = na.fraction * 100,
        colour = class
      ), size = 2) +
      scale_colour_discrete(
        breaks = c("QC", "Subject"),
        labels = c("QC", "Subject"),
        name = "Class"
      ) +
      scale_colour_manual(values = c("#E64B35FF", "#4DBBD5FF")) +
      labs(x = "Injection order", y = "Missing value ratio (%)") +
      geom_hline(
        yintercept = 100 - min.fraction.peak * 100,
        color = "red",
        linetype = 2
      ) +
      ggrepel::geom_text_repel(
        data = dplyr::filter(na.fraction,
                             na.fraction > 1 - min.fraction.peak),
        mapping = aes(x = injection.order, y = na.fraction * 100,
                      label = peak.name)
      ) +
      theme_bw() +
      theme(
        axis.title = element_text(size = 15),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 15),
        legend.text = element_text(size = 12)
      )
    
    plot
    
    if (length(remove.idx.na.fraction) > 0) {
      remove.name <- colnames(subject_qc_data)[remove.idx.na.fraction]
      
      object@sample.info <-
        object@sample.info %>%
        dplyr::filter(., !(sample.name %in% remove.name))
      
      object@ms1.data[[1]] <-
        object@ms1.data[[1]] %>%
        dplyr::select(., -one_of(remove.name))
    }
    
    object@process.info$filterSample <- list()
    object@process.info$filterSample$min.fraction.peak <-
      min.fraction.peak
    object@process.info$filterSample$plot <- plot
    cat("All is done!\n")
    invisible(object)
  }
)



#' @title filterRSD
#' @description Filter peaks according to RSD.
#' @author Xiaotao Shen
#' \email{shenxt1990@@163.com}
#' @param object A metflowClass object.
#' @param slot What group samples are used to calculate RSD.
#' @param rsd.cutoff RSD cutoff.
#' @return A new metflowClass object.
#' @export
setGeneric(
  name = "filterRSD",
  def = function(object,
                 slot = c("Subject", "QC"),
                 rsd.cutoff = 30) {
    slot <- match.arg(slot)
    if (class(object) != "metflowClass") {
      stop("Only the metflowClass is supported!\n")
    }
    if(length(object@ms1.data) > 1){
      stop("Please align batch first.\n")
    }
    
    rsd <- calRSD(object = object, slot = slot)
    
    remain.idx <- which(rsd < rsd.cutoff)
    object@ms1.data <- list(object@ms1.data[[1]][remain.idx, ,drop = FALSE])
    
    object@process.info$filterRSD <- list()
    object@process.info$filterRSD$slot <- slot
    object@process.info$filterRSD$rsd.cutoff <- rsd.cutoff
    invisible(object)
  }
)
