library(data.table)
source("../R/heat4.R")

#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_AnnualIndicatorPath = args[1]
in_configurationFilePath = args[2]
out_AssessmentIndicatorPath = args[3]
verbose = args[4]

## Verbosity
if (is.na(verbose)) {
    verbose <- TRUE
} else if (tolower(verbose) == "false") {
    verbose <- FALSE
} else {
    verbose <- TRUE
}


###################
### Read inputs ###
###################

# Load R input data: AnnualIndicators.csv
# This was HTTP-POSTed by the user, then stored to disk by pygeoapi, and now read by R:
if (verbose) message(paste('Reading annual indicators from', in_AnnualIndicatorPath, '...'))
wk3 = data.table::fread(file=in_AnnualIndicatorPath)
if (verbose) message(paste('Reading annual indicators from', in_AnnualIndicatorPath, '... DONE.'))
# For some reason, this table is different from how it would be had we not
# stored it to CSV and then re-read it - mainly columns that are stored as integer but
# were numeric in the R object.
# One column is stored as <lgcl> with values "NA", and <char> with <NA> in the R object.
# Another difference is that the original R object had a key, which is lost in the CSV:
# Key: <IndicatorID, UnitID, Period>
#
# Fixing the integer/numeric difference, so the script can run:
if (verbose) message(paste('Fixing columns types...'))
columns_to_numeric <- c("IndicatorID", "DepthMin", "DepthMax", "Response", "Applied",
  "GTC_ML", "STC_HM", "STC_ML", "SSC_HM", "SSC_ML", "ACDEV", "IW", "Period", "NMP")
  #"  GTC_HM", "GTC_ML", "STC_HM", "STC_ML", "SSC_HM", "SSC_ML", "ACDEV", "IW", "Period", "NMP")
for (colname in columns_to_numeric) {
    if (verbose) message(paste('  Colname:', colname))
    wk3[[colname]] = as.numeric(wk3[[colname]])
}
if (verbose) message(paste('Fixing columns types... DONE.'))


####################
### Computing... ###
####################

if (verbose) message("Calculating assessment means and confidence assessment...")
wk5 <- compute_assessment_indicators(wk3, in_configurationFilePath, verbose)
if (verbose) message("Calculating assessment means and confidence assessment... DONE.")
if (verbose) message('Calculation done.')


#####################
### Store results ###
#####################

# Should we overwrite old results?
overwrite <- "true" # not boolean, because if we set this via command line arg it is always string!
if (is.na(overwrite)) {
    overwrite <- FALSE
} else if (tolower(overwrite) == "true") {
    overwrite <- TRUE
} else {
    overwrite <- FALSE
}
if (file.exists(out_AssessmentIndicatorPath) && !overwrite) {
    stop(paste0("Output already exists, cannot overwrite (", out_AssessmentIndicatorPath,")"))
}

# Create directory if not exists 
if (!file.exists(dirname(out_AssessmentIndicatorPath))) {
    dir.create(dirname(out_AssessmentIndicatorPath), showWarnings = FALSE, recursive = TRUE)
}

# Actual storing:
if (verbose) message("Storing results...")
data.table::fwrite(wk5, file = out_AssessmentIndicatorPath)
if (verbose) message(paste('Stored result:', out_AssessmentIndicatorPath))
if (verbose) message("Storing results... DONE.")
message('R script finished running.')
