library(sf)         # %>%
library(data.table) # setkey, fread
library(readxl)     # read_excel

compute_assessment <- function(wk5, configurationFile, verbose=TRUE) {
    if (verbose) message("START: compute_assessment")

    indicators <- as.data.table(read_excel(configurationFile, sheet = "Indicators", col_types = c("numeric", "numeric", "text", "text", "text", "text", "numeric", "numeric", "numeric", "numeric", "numeric", "numeric", "text", "numeric", "numeric", "text", "numeric", "numeric", "numeric", "numeric", "numeric", "numeric"))) %>% setkey(IndicatorID)
    indicatorUnits <- as.data.table(read_excel(configurationFile, sheet = "IndicatorUnits", col_types = "numeric")) %>% setkey(IndicatorID, UnitID)

    # Criteria ---------------------------------------------------------------------
    if (verbose) message("Criteria...")

    # Check indicator weights
    if (verbose) message("Check indicator weights...")
    if (verbose) message("(displaying table 'indicators')")
    indicators[indicatorUnits][!is.na(CriteriaID), .(IWs = sum(IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

    # Criteria result as a simple average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
    if (verbose) message("Computing criteria result...")
    wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQRS), .(.N, ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), C = mean(C)), .(CriteriaID, UnitID)]

    # Criteria result as a weighted average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
    #wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQR), .(.N, ER = weighted.mean(ER, IW, na.rm = TRUE), EQR = weighted.mean(EQR, IW, na.rm = TRUE), EQRS = weighted.mean(EQRS, IW, na.rm = TRUE), C = weighted.mean(C, IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

    wk7 <- dcast(wk6, UnitID ~ CriteriaID, value.var = c("N","ER","EQR","EQRS","C"))

    # Assessment -------------------------------------------------------------------
    if (verbose) message("Assessment...")

    # Assessment result - UnitID, N, ER, EQR, EQRS, C
    wk8 <- wk6[, .(.N, ER = max(ER), EQR = min(EQR), EQRS = min(EQRS), C = mean(C)), (UnitID)] %>% setkey(UnitID)

    wk9 <- wk7[wk8, on = .(UnitID = UnitID), nomatch=0]

    # Assign Status and Confidence Classes
    wk9[, EQRS_Class   := ifelse(EQRS >= 0.8, "High",
                          ifelse(EQRS >= 0.6, "Good",
                          ifelse(EQRS >= 0.4, "Moderate",
                          ifelse(EQRS >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_1_Class := ifelse(EQRS_1 >= 0.8, "High",
                          ifelse(EQRS_1 >= 0.6, "Good",
                          ifelse(EQRS_1 >= 0.4, "Moderate",
                          ifelse(EQRS_1 >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_2_Class := ifelse(EQRS_2 >= 0.8, "High",
                          ifelse(EQRS_2 >= 0.6, "Good",
                          ifelse(EQRS_2 >= 0.4, "Moderate",
                          ifelse(EQRS_2 >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_3_Class := ifelse(EQRS_3 >= 0.8, "High",
                          ifelse(EQRS_3 >= 0.6, "Good",
                          ifelse(EQRS_3 >= 0.4, "Moderate",
                          ifelse(EQRS_3 >= 0.2, "Poor","Bad"))))]

    wk9[, C_Class   := ifelse(C >= 75, "High",
                       ifelse(C >= 50, "Moderate", "Low"))]
    wk9[, C_1_Class := ifelse(C_1 >= 75, "High",
                       ifelse(C_1 >= 50, "Moderate", "Low"))]
    wk9[, C_2_Class := ifelse(C_2 >= 75, "High",
                       ifelse(C_2 >= 50, "Moderate", "Low"))]
    wk9[, C_3_Class := ifelse(C_3 >= 75, "High",
                       ifelse(C_3 >= 50, "Moderate", "Low"))]

    if (verbose) message("END:   compute_assessment")
    return(wk9)
}
