# Import packages
library(data.table) # to get "fread"
library(sf)         # to get "%>%"
library(readr)      # to get "read_delim"


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_AssessmentIndicatorPath = args[1]  # file, format: csv. Full path to: AssessmentIndicators.csv
in_indicatorsPath = args[2]           # file, format: csv
in_indicatorUnitsPath = args[3]       # file, format: csv
out_AssessmentPath = args[4]          # file, format: csv, written here. Full path to: Assessment.csv


###################
### Read inputs ###
###################

# Load R input data: AssessmentIndicators.csv
# This was HTTP-POSTed by the user, then stored to disk by pygeoapi, and now read by R:
wk5 = fread(file=in_AssessmentIndicatorPath)

# Load static input data:
print(paste('Reading indicators from', in_indicatorsPath))
indicators = as.data.table(readr::read_delim(in_indicatorsPath, delim=";", col_types = "iicccciiiinncnncnnnnnn")) %>% setkey(IndicatorID)
print(paste('Reading indicator units from', in_indicatorUnitsPath))
indicatorUnits = as.data.table(readr::read_delim(in_indicatorUnitsPath, delim=";", col_types = "iinnnnn")) %>% setkey(IndicatorID, UnitID)


####################################
### Computing wk6, wk7, wk8, wk9 ###
####################################

# Criteria ---------------------------------------------------------------------

# Check indicator weights
indicators[indicatorUnits][!is.na(CriteriaID), .(IWs = sum(IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

# Criteria result as a simple average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQRS), .(.N, ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), C = mean(C)), .(CriteriaID, UnitID)]

# Criteria result as a weighted average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
#wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQR), .(.N, ER = weighted.mean(ER, IW, na.rm = TRUE), EQR = weighted.mean(EQR, IW, na.rm = TRUE), EQRS = weighted.mean(EQRS, IW, na.rm = TRUE), C = weighted.mean(C, IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

wk7 <- dcast(wk6, UnitID ~ CriteriaID, value.var = c("N","ER","EQR","EQRS","C"))

# Assessment -------------------------------------------------------------------

# Assessment result - UnitID, N, ER, EQR, EQRS, C
wk8 <- wk6[, .(.N, ER = max(ER), EQR = min(EQR), EQRS = min(EQRS), C = mean(C)), (UnitID)] %>% setkey(UnitID)

wk9 <- wk7[wk8, on = .(UnitID = UnitID), nomatch=0]

# Assign Status and Confidence Classes
wk9[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
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

wk9[, C_Class := ifelse(C >= 75, "High",
                        ifelse(C >= 50, "Moderate", "Low"))]
wk9[, C_1_Class := ifelse(C_1 >= 75, "High",
                        ifelse(C_1 >= 50, "Moderate", "Low"))]
wk9[, C_2_Class := ifelse(C_2 >= 75, "High",
                        ifelse(C_2 >= 50, "Moderate", "Low"))]
wk9[, C_3_Class := ifelse(C_3 >= 75, "High",
                        ifelse(C_3 >= 50, "Moderate", "Low"))]

print('R script finished running.')


#####################
### Write outputs ###
#####################

print(paste('Now writing outputs to', out_AssessmentPath))
data.table::fwrite(wk9, file = out_AssessmentPath)
print(paste('R script wrote outputs to', out_AssessmentPath))
