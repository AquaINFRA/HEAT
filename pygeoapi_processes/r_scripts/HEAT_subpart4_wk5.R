# Import packages
library(data.table) # to get "fread"
library(readr)      # to get "read_delim"
library(sf)         # to get "%>%"


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_AnnualIndicatorPath = args[1]       # file, format: csv. Full path to: AnnualIndicators.csv
in_indicatorsPath = args[2]            # file, format: csv
in_indicatorUnitsPath = args[3]        # file, format: csv
out_AssessmentIndicatorPath = args[4]  # file, format: csv, written here. Full path to: AssessmentIndicators.csv


###################
### Read inputs ###
###################

# Load R input data: AnnualIndicators.csv
# This was HTTP-POSTed by the user, then stored to disk by pygeoapi, and now read by R:
print(paste('Reading annual indicators from', in_AnnualIndicatorPath))
wk3 = data.table::fread(file=in_AnnualIndicatorPath)
# For some reason, this table is different from how it would be had we not
# stored it to CSV and then re-read it - mainly columns that are stored as integer but
# were numeric in the R object.
# One column is stored as <lgcl> with values "NA", and <char> with <NA> in the R object.
# Another difference is that the original R object had a key, which is lost in the CSV:
# Key: <IndicatorID, UnitID, Period>
#
# Fixing the integer/numeric difference, so the script can run:
print(paste('Fixing columns types...'))
columns_to_numeric <- c("IndicatorID", "DepthMin", "DepthMax", "Response", "Applied",
  #"GTC_ML", "STC_HM", "STC_ML", "SSC_HM", "SSC_ML", "ACDEV", "IW", "Period", "NMP")
  "GTC_HM", "GTC_ML", "STC_HM", "STC_ML", "SSC_HM", "SSC_ML", "ACDEV", "IW", "Period", "NMP")
for (colname in columns_to_numeric) {
  #print(paste('Colname: ', colname))
  wk3[[colname]] = as.numeric(wk3[[colname]])
}

# Load static input data:
print(paste('Reading indicators from', in_indicatorsPath))
indicators = as.data.table(readr::read_delim(in_indicatorsPath, delim=";", col_types = "iicccciiiinncnncnnnnnn")) %>% setkey(IndicatorID)
print(paste('Reading indicator units from', in_indicatorUnitsPath))
indicatorUnits = as.data.table(readr::read_delim(in_indicatorUnitsPath, delim=";", col_types = "iinnnnn")) %>% setkey(IndicatorID, UnitID)


##########################
### Computing wk4, wk5 ###
##########################

# Calculate assessment means --> UnitID, Period, ES, SD, N, N_OBS, EQR, EQRS GTC, STC, SSC
print(paste0('Start calculating wk4...'))
wk4 <- wk3[, .(Period = ifelse(min(Period) > 9999, min(Period), min(Period) * 10000 + max(Period)), ES = mean(ES), SD = sd(ES), ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), N = .N, N_OBS = sum(N), GTC = mean(GTC), STC = mean(STC), SSC = mean(SSC)), .(IndicatorID, UnitID)]


wk4[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
                           ifelse(EQRS >= 0.6, "Good",
                                  ifelse(EQRS >= 0.4, "Moderate",
                                         ifelse(EQRS >= 0.2, "Poor","Bad"))))]


# Add Year Count where STC = 100 --> NSTC100
wk4 <- wk3[STC == 100, .(NSTC100 = .N), .(IndicatorID, UnitID)][wk4, on = .(IndicatorID, UnitID)]

# Adjust Specific Spatial Confidence if number of years where STC = 100 is at least half of the number of years with meassurements
wk4[, STC := ifelse(!is.na(NSTC100) & NSTC100 >= N/2, 100, STC)]

# Combine with indicator and indicator unit configuration tables
print(paste0('Start calculating wk5...'))
wk5 <- indicators[indicatorUnits[wk4]]

# Confidence Assessment---------------------------------------------------------

# Calculate Temporal Confidence averaging General and Specific Temporal Confidence 
wk5 <- wk5[, TC := (GTC + STC) / 2]

wk5[, TC_Class := ifelse(TC >= 75, "High", ifelse(TC >= 50, "Moderate", "Low"))]

# Calculate Spatial Confidence as the Specific Spatial Confidence 
wk5 <- wk5[, SC := SSC]

wk5[, SC_Class := ifelse(SC >= 75, "High", ifelse(SC >= 50, "Moderate", "Low"))]

# Standard Error - using number of years in the assessment period and the associated standard deviation
#wk5[, SE := SD / sqrt(N)]

# Accuracy Confidence for Non-Problem Area
#wk5[, AC_NPA := ifelse(Response == 1, pnorm(ET, ES, SD), pnorm(ES, ET, SD))]

# Standard Error - using number of observations behind the annual mean - to be used in Accuracy Confidence Calculation!!!
wk5[, AC_SE := SD / sqrt(N_OBS)]

# Accuracy Confidence for Non-Problem Area
wk5[, AC_NPA := ifelse(Response == 1, pnorm(ET, ES, AC_SE), pnorm(ES, ET, AC_SE))]

# Accuracy Confidence for Problem Area
wk5[, AC_PA := 1 - AC_NPA]

# Accuracy Confidence Area Class - Not sure what this should be used for?
#wk5[, ACAC := ifelse(AC_NPA > 0.5, "NPA", ifelse(AC_NPA < 0.5, "PA", "PPA"))]

# Accuracy Confidence
wk5[, AC := ifelse(AC_NPA > AC_PA, AC_NPA, AC_PA)]

# Accuracy Confidence Class
wk5[, ACC := ifelse(AC > 0.9, 100, ifelse(AC < 0.7, 0, 50))]

wk5[, ACC_Class := ifelse(ACC >= 75, "High", ifelse(ACC >= 50, "Moderate", "Low"))]

# Calculate Overall Confidence
wk5 <- wk5[, C := (TC + SC + ACC) / 3]

wk5[, C_Class := ifelse(C >= 75, "High", ifelse(C >= 50, "Moderate", "Low"))]

print('R script finished running.')

#####################
### Write outputs ###
#####################

print(paste('Now writing outputs to', out_AssessmentIndicatorPath))
data.table::fwrite(wk5, file = out_AssessmentIndicatorPath)
print(paste('R script wrote outputs to', out_AssessmentIndicatorPath))

