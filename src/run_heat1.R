library(sf) # st_write
source("../R/all_heat_functions.R")
source("../R/heat_plot_functions.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
assessmentPeriod = args[1]
in_unitsFilePath = args[2]
in_unitGridSizePath = args[3]
out_unitsCleanedFilePath = args[4]
out_unitsGriddedFilePath = args[5]
out_plotsPath = args[6] # NA if not passed by user, then interpreted as "don't plot"
verbose = args[6]

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

unitGridSizeTable <- get_unit_grid_size_table(in_unitGridSizePath, format='xlsx')


####################
### Computing... ###
####################

## Generate assessment units and gridunits
units <- get_units(assessmentPeriod, in_unitsFilePath, verbose)
gridunits <- get_gridunits(units, unitGridSizeTable, verbose)
if (verbose) message('Calculation done.')


################
### Plotting ###
################

## Plot them, if desired
if (!is.na(out_plotsPath)) {

    if (!file.exists(out_plotsPath)) {
        dir.create(out_plotsPath, showWarnings = FALSE, recursive = TRUE)
    }

    # Plot the assessment units
    if (verbose) message(paste('Storing PNG graphics to', out_plotsPath))
    #pdf(file = NULL)
    plot_spatial_units(units, out_plotsPath, "Assessment_Units.png")

    # Plot the gridded units:
    plot_spatial_units(st_cast(gridunits), out_plotsPath, "Assessment_GridUnits.png")

    # Plot the individual ones:
    gridunits10 <- make.gridunits(units, 10000, verbose)
    gridunits30 <- make.gridunits(units, 30000, verbose)
    gridunits60 <- make.gridunits(units, 60000, verbose)
    plot_spatial_units(gridunits10, out_plotsPath, "Assessment_GridUnits10.png")
    plot_spatial_units(gridunits30, out_plotsPath, "Assessment_GridUnits30.png")
    plot_spatial_units(gridunits60, out_plotsPath, "Assessment_GridUnits60.png")
    if (verbose) message(paste('Stored into', out_plotsPath, ': Assessment_Units.png, Assessment_GridUnits10.png, Assessment_GridUnits20.png, Assessment_GridUnits60.png, Assessment_GridUnits.png'))
}


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
if (file.exists(out_unitsGriddedFilePath) && !overwrite) {
    stop(paste0("Output already exists, cannot overwrite (", out_unitsGriddedFilePath,")"))
}
if (file.exists(out_unitsCleanedFilePath) && !overwrite) {
    stop(paste0("Output already exists, cannot overwrite (", out_unitsCleanedFilePath,")"))
}

# Create directory if not exists 
if (!file.exists(dirname(out_unitsGriddedFilePath))) {
    dir.create(dirname(out_unitsGriddedFilePath), showWarnings = FALSE, recursive = TRUE)
}
if (!file.exists(dirname(out_unitsCleanedFilePath))) {
    dir.create(dirname(out_unitsCleanedFilePath), showWarnings = FALSE, recursive = TRUE)
}

# Actual storing:
if (verbose) message("Storing results...")
sf::st_write(gridunits, out_unitsGriddedFilePath, delete_layer = TRUE, append=FALSE)
if (verbose) message(paste('Stored result:', out_unitsGriddedFilePath))
sf::st_write(units, out_unitsCleanedFilePath, append=FALSE)
if (verbose) message(paste('Stored result:', out_unitsCleanedFilePath))
if (verbose) message("Storing results... DONE.")
message('R script finished running.')
