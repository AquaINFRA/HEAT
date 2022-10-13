# ----------------------------
#
#   Model spatial profiles
#
#     * load profile parameters and fit spatial temporal models
#
# ----------------------------

# load packages etc.
header("model")

# Define paths
inputPath <<- file.path("OxygenDebt/Input", assessmentPeriod)
outputPath <<- file.path("OxygenDebt/Output", assessmentPeriod)

# start timer
t0 <- proc.time()

# read profile fits
profiles <- read.csv(file.path(outputPath, "oxy_profiles.csv"))
#profiles <- fread(file.path(outputPath, "oxy_profiles.csv"))

# convert to factor
profiles$Basin <- factor(profiles$Basin)

# ----------------------------
#
#  model spatial distribution of halocline
#
# ----------------------------

# set model
form <- as.formula(
          sprintf("val ~ s(x, y, k = 20) +
                   s(yday, bs = 'cc', k = 6, by = Basin) +
                   s(Basin, bs = 're') +
                   s(Year, k = %i, bs = 'tp', m = 1, by = Basin)", length(unique(profiles$Year))))

#form <- val ~ te(x, y, Year, k = c(20, 5), d = c(2,1), m = c(2,1), bs = c("tp", "tp")) +
#              te(x, y, yday, k = c(10, 6), d = c(2,1), bs = c("tp", "cc"))

# fit gams
what <- c("sali_surf", "sali_dif", "halocline", "depth_gradient",
          "O2def_below_halocline")

fitfunc1 <-
  function(what) {
    profiles$val <- log(profiles[[what]])
    gam(form, data = profiles, drop.unused.levels = FALSE)
  }

gams <- lapply(what, fitfunc1)
names(gams) <- what

# substitute zeros for smallest non zero in slope estimate
fitfunc2 <-
  function(what) {
    profiles$val <- log(profiles[[what]])
    profiles$val[which(profiles[[what]] == 0)] <- min(profiles[which(profiles[[what]] > 0),what])
    gam(form, data = profiles, drop.unused.levels = FALSE)
  }

gams$O2def_slope_below_halocline <- fitfunc2("O2def_slope_below_halocline")


# save
save(gams, file = file.path(outputPath, "oxy_gam_fits.RData"))

# done -------------------

message(sprintf("time elapsed: %.2f seconds", (proc.time() - t0)["elapsed"]))
