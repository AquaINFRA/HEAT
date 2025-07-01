library(sf) # st_write
source("../R/all_heat_functions.R")
source("../R/heat_plot_functions.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_unitsFilePath = args[1]
in_unitGridSizePath = args[2]
out_unitsCleanedFilePath = args[3]
out_unitsGriddedFilePath = args[4]
out_plotsPath = args[5] # NA if not passed by user, then interpreted as "don't plot"
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


####################
### Computing... ###
####################

## Generate assessment units and gridunits
# Units: Transform to EPSG 3035, filter based on Code=SEA if applicable, ...
holas_period <- NULL # Not operating on any predefined HOLAS period here!
units <- get_units(holas_period, in_unitsFilePath, verbose)
unitGridSizeTable <- get_unit_grid_size_table(in_unitGridSizePath, format='csv')
if (verbose) message(paste('unitGridSizeTable: ', paste(unitGridSizeTable$GridSize, collapse=", ")))
#gridunits <- get_gridunits(units, unitGridSizeTable, verbose)
gridunits <- get_gridunits_generic(units, unitGridSizeTable, verbose)
if (verbose) message('Calculation done.')


################
### Plotting ###
################

## Plot them, if desired
## TODO: THis still contains the fixed grid sizes!!
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
    gridunits30 <- make.gridunits(units, 20000, verbose)
    gridunits60 <- make.gridunits(units, 50000, verbose)
    plot_spatial_units(gridunits10, out_plotsPath, "Assessment_GridUnits10.png")
    plot_spatial_units(gridunits30, out_plotsPath, "Assessment_GridUnits20.png")
    plot_spatial_units(gridunits60, out_plotsPath, "Assessment_GridUnits50.png")
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
