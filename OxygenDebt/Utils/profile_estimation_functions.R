## The profile estimation procedure


# ----------------------------
#
# profile functions
#
# ----------------------------

#' @export
# define salinity profile
sali_profile <- function(depth, pars) {
  # requires a vector 'pars' with names: sali_surf, sali_dif, halocline, depth_gradient
  with(pars, sali_surf + sali_dif * pnorm(depth, halocline, depth_gradient))
}


#' @export
# define oxygen profile
oxy_profile <- function(depth, pars) {
  # requires a vector 'pars' with names:
  #     depth_change_point1, depth_change_point2
  #     O2def_below_halocline, O2def_slope_below_halocline
  mod1 <- function(x) {
    rep(0, length(x))
  }
  mod2 <- function(x) {
    if (is.na(pars$O2def_below_halocline)) {
      rep(NA, length(x))
    } else {
      approx(c(pars$depth_change_point1, pars$depth_change_point2),
             c(0, pars$O2def_below_halocline), x)$y
    }
  }
  mod3 <- function(x) {
    if (is.na(pars$O2def_slope_below_halocline)) {
      rep(NA, length(x))
    } else {
      (x - pars$depth_change_point2) * pars$O2def_slope_below_halocline + pars$O2def_below_halocline
    }
  }

  ifelse(depth < pars$depth_change_point1,
           mod1(depth),
    ifelse(depth < pars$depth_change_point2,
             mod2(depth),
                mod3(depth)))
}



