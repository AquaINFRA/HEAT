# ----------------------------
#
# profile estimation function
#
# ----------------------------


#' @export

#' @importFrom stats lm
#' @importFrom stats nls
#' @importFrom stats coef
#' @importFrom stats vcov
#' @importFrom stats approx
#' @importFrom survival survreg
#' @importFrom survival Surv
#' @importFrom survival survreg.control

if (FALSE) {
  id <- 6679
  data <- subset(oxy, ID == id)
  ID <- id
}



doonefit_full <- function(data, debug = FALSE, ID) {
  if (debug) {
    cat(rep(" ", 30), "\rID:", data$ID[1])
  }

  # output container
  fit <- data.frame(ID = ID,
                    sali_surf = NA,
                    sali_dif = NA, halocline = NA, depth_gradient = NA,
                    sali_dif.se = NA, halocline.se = NA, depth_gradient.se = NA,
                    depth_change_point1 = NA,
                    depth_change_point2 = NA, depth_change_point2.se = NA,
                    O2def_below_halocline = NA, O2def_slope_below_halocline = NA,
                    O2def_slope_below_halocline.se = NA,
                    notes = "")

  # only proceed if there are enough obs to estimate surface salinity
  wk <- data$Salinity[data$Depth >= data$surfacedepth1 &
                        data$Depth <= data$surfacedepth2]
  if (sum(!is.na(wk)) < 2) {
    fit$notes <- "too few salinity observations in surface layer"
    return(fit)
  }

  # compute sali_surf (this should change by basin)
  data$sali_surf <-
    fit$sali_surf <-
    mean(data$Salinity[data$Depth >= data$surfacedepth1 &
                         data$Depth <= data$surfacedepth2], na.rm = TRUE)

  # strip off data for salinity modelling
  sal <- data[!is.na(data$Salinity) & data$Depth >= 20 & data$max_depth >= data$salmod_max_depth,]
  if (nrow(sal) < 4) {
    fit$notes <- "too few salinity observations below surface"
    return(fit)
  }

  # define lower bound for halocline
  hlower <- sal$salmod_halocline_lower[1]

  # set up weights
  sal$weights <- 1
  sal$weights[sal$Depth >= sal$salmod_wt_depth1 & sal$Depth <= sal$salmod_wt_depth2] <- sal$salmod_wt[1]

  # fit salinity profile
  model <- try(
    nls(Salinity ~ sali_surf + sali_dif * pnorm(Depth, halocline, depth_gradient),
        data = sal,
        lower = list(sali_dif = -0.5, halocline =  hlower, depth_gradient =   1),
        start = list(sali_dif =  4  , halocline =      50, depth_gradient =  10),
        upper = list(sali_dif =  Inf, halocline =     120, depth_gradient = 100),
        weights = sal$weights,
        algorithm = "port"), silent = TRUE)
  if (inherits(model, "try-error")) {
    fit$notes <- "salinity model failure to converge"
    return(fit)
  }
  fit[names(coef(model))] <- coef(model)

  # calculate change points
  fit$depth_change_point1 <- with(fit, halocline - 1.0 * depth_gradient)
  fit$depth_change_point2 <- with(fit, halocline + 1.0 * depth_gradient)
  # describe above as a matrix operation
  X <- matrix(c(0,1,1), 1, 3) # i.e. depth_change_point2 = X %*% coef(model)
  # calculate standard error of depth_change_point2 by assuming normal errors for parameter estimates
  # this is used to identify dodgy / unreliable fits
  if (any(diag(model$m$Rmat()) == 0)) {
    # singular fit - unreliable - set ses to very large value
    fit$depth_change_point2.se <- 1000
    fit$sali_dif.se <- 1000
  } else {
    fit$depth_change_point2.se <- sqrt(drop(X %*% vcov(model) %*% t(X)))
    fit$sali_dif.se <- sqrt(diag(vcov(model)))["sali_dif"]
    fit$halocline.se <- sqrt(diag(vcov(model)))["halocline"]
    fit$depth_gradient.se <- sqrt(diag(vcov(model)))["depth_gradient"]
  }
  # compute number of datapoints above halocline depth


  # compute oxygen deficit
  # strip off data for oxygen modelling
  O2 <- data[!is.na(data$Oxygen_deficit),]

  # estimate O2 deficit level in surface layer ?
  # No - this is hardwired to zero, but could be done like this
  # fit$O2def_seg1_level <- mean(O2$Oxygen_deficit[O2$Depth < fit$depth_change_point1])

  # calculate O2 for second change point
  id <- which(O2$Depth > fit$depth_change_point2)[1]
  if (nrow(O2) < 2 || is.na(id) || id == 1) {
    # no data above change point or no data below change point
    fit$notes <- "no O2 data above change point or no data below change point"
    return(fit)
  }
  id <- id  + -1:0
  if (diff(O2$Depth[id]) > 30) {
    # use depth
    fit$O2def_below_halocline <- approx(O2$Depth[id], O2$Oxygen_deficit[id], xout = fit$depth_change_point2)$y
  } else {
    # use salinity curve
    sali_preds <- sali_profile(O2$Depth[id], fit)
    sali_change_point2 <- sali_profile(fit$depth_change_point2, fit)
    fit$O2def_below_halocline <- approx(sali_preds, O2$Oxygen_deficit[id], xout = sali_change_point2)$y
  }

  # estimate model for 3rd segment
  O2_slope <- O2[O2$Depth > fit$depth_change_point2,]

  # if not enough data return
  if (nrow(O2_slope[O2_slope$censor == 0,]) < 2) {
    fit$notes <- "too few uncensored O2 observations below halocline"
    return(fit)
  }

  # recenter data to easily estimate the slope
  O2_slope$Oxygen_deficit <- O2_slope$Oxygen_deficit - fit$O2def_below_halocline
  O2_slope$Depth <- O2_slope$Depth - fit$depth_change_point2

  # if there are any censored data:
  if (any(O2_slope$censor == 1)) {

    # Fit a `tobit regression': a standard
    # linear regression with Gaussian errors, and left censored data.
    seg3_model <-
      suppressWarnings(
        survival::survreg(survival::Surv(Oxygen_deficit, !censor, type='right') ~ Depth - 1,
                            data=O2_slope,
                            dist='gaussian',
                            control = survival::survreg.control(maxiter=1000))
      )
    # TODO add in convergence warning if given
    # fit$notes <- ...
    fit$O2def_slope_below_halocline.se <- seg3_model$var["Depth",1]
  } else {
    # Fit the non censored version
    seg3_model <- lm(Oxygen_deficit ~ Depth - 1, data = O2_slope)
    fit$O2def_slope_below_halocline.se <- summary(seg3_model)$coefficients["Depth", 2]
  }

  # save the estimate (slope must be positive)
  fit$O2def_slope_below_halocline <- pmax(0,coef(seg3_model))

  fit$notes <- "success"

  fit
}

