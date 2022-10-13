# ----------------------------
#
#   Prepare compiled data for analysis
#
#     * read compiled data from output folder
#     * prepare data for analysis and write to output folder
#
# ----------------------------

# load packages etc.
header("input")

# Define paths
inputPath <<- file.path("OxygenDebt/Input", assessmentPeriod)
outputPath <<- file.path("OxygenDebt/Output", assessmentPeriod)

# start timer
t0 <- proc.time()

# ----------------------------
#
#  read oxy data
#
# ----------------------------

oxy <- fread(file.path(outputPath, "oxy.csv"))

# ----------------------------
#
#  tidy data and form new variables
#
# ----------------------------

# compute number of oxygen observations per station
oxy$n_Oxygen <- c(with(oxy, tapply(Oxygen, ID, function(x) sum(!is.na(x))))[paste(oxy$ID)])

# compute max (non NA) oxygen sample depth per station
oxy$max_depth <- c(with(oxy, tapply(Depth, ID, max))[paste(oxy$ID)])

# oxygen observations are in ml/l - convert to mg/l
oxy$Oxygen_ml <- oxy$Oxygen
oxy$Oxygen <- oxy$Oxygen_ml * 1.428 # or / 0.700

# compute oxygen deficit
oxy$Oxygen_deficit <- O2satFun(oxy$Temperature) - oxy$Oxygen

# checks
if (FALSE) {
  plot(oxy$Oxygen, oxy$Hydrogen_Sulphide)
  plot(oxy$Oxygen_deficit, oxy$Hydrogen_Sulphide)
}

# supersaturation not realistic below 30 m - error
oxy$Oxygen_deficit[which(oxy$Oxygen_deficit < 0 & oxy$Depth>30)] <- NA

# drop missing observations ? - I think so - why keep double NA rows ?
oxy <- subset(oxy, !is.na(Salinity) | !is.na(Oxygen_deficit))

# set up censoring rules for oxygen deficit slope below halocline:
#     1. do not use CTD data close to zero as they go constant
#     2. censoring and no measurement of H2S ? - not implemented
#O2_slope$censor <- (O2_slope$Type == "BOT" & O2_slope$Oxygen < 1) |
#                   (O2_slope$Type == "WQ"  & O2_slope$Oxygen == 0)
oxy$censor <- 0
oxy$censor[oxy$Type == 'CTD' & oxy$Oxygen < 1] <- 1 # do not use CTD data close to zero as they go constant;
#oxy$censor[which(oxy$Type == 'BOT' & oxy$Oxygen == 0)] <- 1 # censoring and no measurement of H2S;
oxy$censor[is.na(oxy$Hydrogen_Sulphide) & oxy$Oxygen == 0] <- 1 # censoring and no measurement og H2S;

# oxygen deficit should not be negative ?
oxy$Oxygen_deficit[oxy$Oxygen_deficit < 0] <- 0


if (FALSE) {
  # inspect
  str(oxy)
  length(unique(oxy$ID))
  # report to file - the number of records read in ?
  # which(with(unique(oxy[c("StationID", "ID")]), table(ID)) > 1)
}


# set up covariates for modelling
oxy$date <- lubridate::ymd(with(oxy, paste(Year, Month, Day, sep = "-")))
oxy$yday <- lubridate::yday(oxy$date)
oxy$Basin <- factor(oxy$Basin)

# select data

# write data --------------------

fwrite(oxy, file.path(outputPath, "oxy_clean.csv"))

# done -------------------

message(sprintf("time elapsed: %.2f seconds", (proc.time() - t0)["elapsed"]))
