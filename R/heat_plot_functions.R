library(ggplot2)


plot_spatial_units <- function(polygons, outputPath, fileName) {
  ggplot() + geom_sf(data = polygons) + coord_sf()
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
}


get_EQRS_colors <- function() {
  EQRS_Classes <- list(
    EQRS_Class_colors = c(rgb(119,184,143,max=255), rgb(186,215,194,max=255), rgb(235,205,197,max=255), rgb(216,161,151,max=255), rgb(199,122,112,max=255)),
    EQRS_Class_limits = c("High", "Good", "Moderate", "Poor", "Bad"),
    EQRS_Class_labels = c(">= 0.8 - 1.0 (High)", ">= 0.6 - 0.8 (Good)", ">= 0.4 - 0.6 (Moderate)", ">= 0.2 - 0.4 (Poor)", ">= 0.0 - 0.2 (Bad)")
  )
  return(EQRS_Classes)
}


get_C_colors <- function() {
  C_Classes <- list(
    C_Class_colors = c(rgb(252,231,218,max=255), rgb(245,183,142,max=255), rgb(204,100,23,max=255)),
    C_Class_limits = c("High", "Moderate", "Low"),
    C_Class_labels = c(">= 75 % (High)", "50 - 74 % (Moderate)", "< 50 % (Low)")
  )
  return(C_Classes)
}


plot_assessment_indicator_maps <- function(wk5, units, indicators, EQRS_Classes, C_Classes, outputPath, verbose=TRUE) {

  EQRS_Class_colors <- EQRS_Classes$EQRS_Class_colors
  EQRS_Class_limits <- EQRS_Classes$EQRS_Class_limits
  EQRS_Class_labels <- EQRS_Classes$EQRS_Class_labels
  C_Class_colors <- C_Classes$C_Class_colors
  C_Class_limits <- C_Classes$C_Class_limits
  C_Class_labels <- C_Classes$C_Class_labels

  n <- nrow(indicators[IndicatorID < 1000,])
  for(i in 1:n) {
    indicatorID <- indicators[i, IndicatorID]
    indicatorCode <- indicators[i, Code]
    indicatorName <- indicators[i, Name]
    if (verbose) message(paste0("  Iteration ", i, "/", n, ", indicator name: ", indicatorName))
    indicatorYearMin <- indicators[i, YearMin]
    indicatorYearMax <- indicators[i, YearMax]
    indicatorMonthMin <- indicators[i, MonthMin]
    indicatorMonthMax <- indicators[i, MonthMax]
    indicatorDepthMin <- indicators[i, DepthMin]
    indicatorDepthMax <- indicators[i, DepthMax]
    indicatorYearMin <- indicators[i, YearMin]
    indicatorMetric <- indicators[i, Metric]

    wk <- wk5[IndicatorID == indicatorID] %>% setkey(UnitID)

    wk <- merge(units, wk, by = "UnitID", all.x = TRUE)  

    # Status map (EQRS)
    title <- paste0("Eutrophication Status ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
    fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_EQRS", ".png"))
    if (verbose) message(paste("  Will store to", fileName))

    ggplot(wk) +
      labs(title = title , subtitle = subtitle) +
      geom_sf(aes(fill = EQRS_Class)) +
      scale_fill_manual(name = "EQRS", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
    ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)

    # Temporal Confidence map (TC)
    title <- paste0("Eutrophication Temporal Confidence ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
    fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_TC", ".png"))
    if (verbose) message(paste("  Will store to", fileName))

    ggplot(wk) +
      labs(title = title , subtitle = subtitle) +
      geom_sf(aes(fill = TC_Class)) +
      scale_fill_manual(name = "TC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
    ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)

    # Spatial Confidence map (SC)
    title <- paste0("Eutrophication Spatial Confidence ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
    fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_SC", ".png"))
    if (verbose) message(paste("  Will store to", fileName))

    ggplot(wk) +
      labs(title = title , subtitle = subtitle) +
      geom_sf(aes(fill = SC_Class)) +
      scale_fill_manual(name = "SC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
    ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)

    # Accuracy Confidence Class map (ACC)
    title <- paste0("Eutrophication Accuracy Class Confidence ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
    fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_ACC", ".png"))
    if (verbose) message(paste("  Will store to", fileName))

    ggplot(wk) +
      labs(title = title , subtitle = subtitle) +
      geom_sf(aes(fill = ACC_Class)) +
      scale_fill_manual(name = "ACC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
    ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)

    # Confidence map (C)
    title <- paste0("Eutrophication Confidence ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
    fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_C", ".png"))
    if (verbose) message(paste("  Will store to", fileName))

    ggplot(wk) +
      labs(title = title , subtitle = subtitle) +
      geom_sf(aes(fill = C_Class)) +
      scale_fill_manual(name = "C", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
    ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
  }
}


plot_status_maps <- function(wk9, units, assessmentPeriod, EQRS_Classes, C_Classes, outputPath, verbose=TRUE) {

  EQRS_Class_colors <- EQRS_Classes$EQRS_Class_colors
  EQRS_Class_limits <- EQRS_Classes$EQRS_Class_limits
  EQRS_Class_labels <- EQRS_Classes$EQRS_Class_labels
  C_Class_colors <- C_Classes$C_Class_colors
  C_Class_limits <- C_Classes$C_Class_limits
  C_Class_labels <- C_Classes$C_Class_labels

  wk <- merge(units, wk9, all.x = TRUE, by = "UnitID")

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
    geom_sf(aes(fill = EQRS_Class)) +
    scale_fill_manual(name = "EQRS", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_EQRS.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_EQRS.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
    geom_sf(aes(fill = EQRS_1_Class)) +
    scale_fill_manual(name = "EQRS_1", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_EQRS_1.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_EQRS_1.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
    geom_sf(aes(fill = EQRS_2_Class)) +
    scale_fill_manual(name = "EQRS_2", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_EQRS_2.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_EQRS_2.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
    geom_sf(aes(fill = EQRS_3_Class)) +
    scale_fill_manual(name = "EQRS_3", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_EQRS_3.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_EQRS_3.png"))

  # Confidence maps
  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
    geom_sf(aes(fill = C_Class)) +
    scale_fill_manual(name = "C", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_C.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_C.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
    geom_sf(aes(fill = C_1_Class)) +
    scale_fill_manual(name = "C_1", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_C_1.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_C_1.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
    geom_sf(aes(fill = C_2_Class)) +
    scale_fill_manual(name = "C_2", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_C_2.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_C_2.png"))

  ggplot(wk) +
    ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
    geom_sf(aes(fill = C_3_Class)) +
    scale_fill_manual(name = "C_3", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, "Assessment_Map_C_3.png"), width = 12, height = 9, dpi = 300)
  if (verbose) message(paste("  Will store to Assessment_Map_C_3.png"))
}


plot_annual_indicator_barcharts <- function(wk3, units, indicators, outputPath, verbose=TRUE) {

  n <- nrow(indicators[IndicatorID < 1000,])
  for(i in 1:n) {
    indicatorID <- indicators[i, IndicatorID]
    indicatorCode <- indicators[i, Code]
    indicatorName <- indicators[i, Name]
    if (verbose) message(paste0("  Iteration ", i, "/", n, ", indicator name: ", indicatorName))
    indicatorUnit <- indicators[i, Units]
    indicatorYearMin <- indicators[i, YearMin]
    indicatorYearMax <- indicators[i, YearMax]
    indicatorMonthMin <- indicators[i, MonthMin]
    indicatorMonthMax <- indicators[i, MonthMax]
    indicatorDepthMin <- indicators[i, DepthMin]
    indicatorDepthMax <- indicators[i, DepthMax]
    indicatorYearMin <- indicators[i, YearMin]
    indicatorMetric <- indicators[i, Metric]

    for (j in 1:nrow(units)) {
      unitID <- as.data.table(units)[j, UnitID]
      unitCode <- as.data.table(units)[j, Code]
      unitName <- as.data.table(units)[j, Description]
      title <- paste0("Eutrophication State [ES, CI, N] and Threshold [ET] ", indicatorYearMin, "-", indicatorYearMax)
      subtitle <- paste0(indicatorName, " (", indicatorCode, ")", " in ", unitName, " (", unitCode, ")", "\n")
      subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
      subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
      subtitle <- paste0(subtitle, "Metric: ", indicatorMetric, ", ")
      subtitle <- paste0(subtitle, "Unit: ", indicatorUnit)
      fileName <- gsub(":", "", paste0("Annual_Indicator_Bar_", indicatorCode, "_", unitCode, ".png"))
      if (verbose) message(paste("  Will store to", fileName))

      wk <- wk3[IndicatorID == indicatorID & UnitID == unitID]

      if (nrow(wk) > 0) {
        ggplot(wk, aes(x = factor(Period, levels = indicatorYearMin:indicatorYearMax), y = ES)) +
          labs(title = title , subtitle = subtitle) +
          geom_col() +
          geom_text(aes(label = N), vjust = -0.25, hjust = -0.25) +
          geom_errorbar(aes(ymin = ES - CI, ymax = ES + CI), width = .2) +
          geom_hline(aes(yintercept = ET)) +
          scale_x_discrete(NULL, factor(indicatorYearMin:indicatorYearMax), drop=FALSE) +
          scale_y_continuous(NULL)

        ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
      }
    }
  }
}