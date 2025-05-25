source("../R/all_heat_functions.R")


## Retrieve command line arguments
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
assessmentPeriod = args[1]
inputPath = args[2]

# Remove trailing slash from input path
if (endsWith(inputPath, "/")) {
    inputPath <- str_sub(inputPath, end = -2)
}

# Concatenate input path
inputPath <- file.path(inputPath, assessmentPeriod)

# Create dir if not exists 
if (!file.exists(dirname(inputPath))) {
    dir.create(dirname(inputPath), showWarnings = FALSE, recursive = TRUE)
}

# Download data
paths <- download_inputs(assessmentPeriod, inputPath)

# Display paths:
message(paste('Stored input data for', assessmentPeriod, 'in:', inputPath))
for (p in paths) {
    message(p)
}

message('R script finished running.')
