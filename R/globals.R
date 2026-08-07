#' @importFrom stats as.formula lm median qnorm
#' @importFrom graphics abline axis grid points
#' @importFrom zaminfluence ComputeModelInfluence AppendTargetRegressorInfluence GetInferenceSignals
#' @import dplyr
#' @import stringr
#' @import estimatr
#' @import tidyr
NULL

# This tells R's strict package checker to ignore unquoted tidyverse column names
utils::globalVariables(c(
  "profile", "profile_opponent", "influence",
  "contest_id", "count", "respondent",
  "weight", "respondent_id"
))
