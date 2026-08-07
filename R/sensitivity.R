#' Analyze Contest Sensitivity
#'
#' @description Evaluates data at the contest level to determine the sensitivity of AMCEs to the removal of influential contests.
#'
#' @param formula An object of class "formula" representing the model to be fitted.
#' @param data A data frame containing the conjoint survey data.
#' @param respondent_id String name of the respondent ID column.
#' @param contest_no String name of the contest number column.
#' @param var_interest String name of the variable of analysis (the target AMCE to analyze the sensitivity).
#' @param target String, either "sign" or "significance".
#' @param weights Optional string name of the weights column.
#' @return A list containing the following components:
#' \describe{
#'   \item{ContestSensitivity}{A data frame containing the sensitivity analysis results, including original model estimates, the number of influential contests dropped to reverse the result, and the updated rerun estimates.}
#'   \item{DroppedContests}{A vector containing the unique IDs of the specific contests that were dropped to achieve the reversal.}
#'   \item{ProfileKey}{A data frame mapping the numeric `profile_id` to their original string `profile` combinations for reference.}
#'   \item{RerunData}{A data frame containing the cleaned conjoint data utilized for the reruns, excluding the dropped metadata and influence scores.}
#' }
#' @export
AnalyzeContestSensitivity = function(formula, data, respondent_id, contest_no,
                                     var_interest, target, weights=NULL){

  if(!is.data.frame(data)){
    stop("Data should be a data frame. Verify is.data.frame(data) is TRUE.")
  }

  out = list()
  out_df = data.frame(param_name = var_interest)
  out_df$target = target

  # Get analysis data and influence scores ------
  QInfl = GetContestInfluences(formula, data, respondent_id, contest_no,
                               var_interest, target, weights)

  # Catch the warning/error return from GetContestInfluences
  if(length(QInfl[[1]]) == 1){
    if(QInfl[[1]] == "Error (3)"){
      message("Returning the subset of data causing NAs.")
      return(QInfl)
    }
  }

  # Add original coef and se with full data to output data frame
  ConjointResults = QInfl[[5]]
  out$ConjointResults = ConjointResults

  model_coef = ConjointResults$coefficients[var_interest]
  out_df$model_coef = model_coef
  model_se = ConjointResults$std.error[var_interest]
  out_df$model_se = model_se
  model_p = ConjointResults$p.value[var_interest]
  out_df$model_p = model_p

  # Sensitivity analysis ------
  df = QInfl[[1]]$contest   # contest-level data with influence scores
  drop_neg_inf = QInfl[[2]] # True if dropping negative influences
  Delta = QInfl[[3]]        # Target quantity
  cj_df = QInfl[[4]]        # Conjoint data with analysis variables (before aggregating)

  out_df$total_infl = sum(df$contest_infl)
  out_df$n_contest = nrow(df)

  # Add median contest influence & neg/pos contest influences to out_df
  if (!drop_neg_inf){
    out_df['median_infl'] = median(df$contest_infl)
    out_df['n_pos_infl']  = sum(df$contest_infl>0)
    out_df['n_neg_infl']  = sum(df$contest_infl<0)
  } else{
    out_df['median_infl'] = -median(df$contest_infl)
    out_df['n_pos_infl']  = sum(df$contest_infl<0)
    out_df['n_neg_infl']  = sum(df$contest_infl>0)
  }

  # Sort influences and calculate cumulative influences of contests -----
  contest_infl = sort(df$contest_infl, decreasing = T)
  cum_infl = cumsum(contest_infl)

  # Determine initial values for reruns
  if(sum(cum_infl > Delta) > 0){
    upper_bound_n_dropped = which(cumsum(cum_infl > Delta) == 1)
    v = rerun_lmrobust(ndrop = upper_bound_n_dropped, infl_df = df,
                       analysis = "contest", formula_=formula, dat=cj_df,
                       var_interest = var_interest)

    not_reversed = !reversed(target = target, rerun = v[[1]],
                             model = c(model_coef, model_se, model_p))
    if(not_reversed){
      upper_bound_n_dropped = upper_bound_n_dropped + 10
      v = rerun_lmrobust(ndrop = upper_bound_n_dropped, infl_df = df,
                         analysis = "contest", formula_=formula, dat=cj_df,
                         var_interest = var_interest)

      not_reversed = !reversed(target = target, rerun = v[[1]],
                               model = c(model_coef, model_se, model_p))
      if(not_reversed){
        upper_bound_n_dropped = upper_bound_n_dropped + 10
      }
    }

    out_df$n_drop_auto = upper_bound_n_dropped
    if(upper_bound_n_dropped == 1){
      out_df$n_drop = upper_bound_n_dropped
      out_df$rerun_coef = v[[1]][1]
      out_df$rerun_se = v[[1]][2]
      out_df$rerun_pval = v[[1]][3]
      out_df$reruns = 1

      df_ordered = df[order(df$contest_infl, decreasing = T), ]
      contests_dropped = df_ordered[1, ]$contest_id

      out$ContestSensitivity = out_df
      out$DroppedContests = contests_dropped
      out$ProfileKey = unique(cj_df[,c("profile_id", "profile")])
      out$RerunData = subset(cj_df, select = -c(profile, profile_opponent, influence))
      return(out)
    }
  } else {
    out_df$n_drop_auto = NA
    upper_bound_n_dropped = sum(contest_infl>0)
  }

  # RERUNS -----
  rerun_counter = 0
  s = seq(from = upper_bound_n_dropped-1, to = 1, by=-1)
  for(i in s){
    rerun_out = rerun_lmrobust(ndrop = i, infl_df = df, analysis = "contest",
                               formula_ = formula, dat = cj_df,
                               var_interest = var_interest)
    rerun_counter = rerun_counter + 1

    if(reversed(target = target, rerun = rerun_out[[1]], model = c(model_coef, model_se, model_p))){
      # Continue dropping
    } else {
      out_df$n_drop = i+1

      final_rerun = rerun_lmrobust(ndrop = i+1, infl_df = df, analysis = "contest",
                                   formula_=formula, dat = cj_df,
                                   var_interest = var_interest)
      rerun_counter = rerun_counter + 1

      out_df$rerun_coef = final_rerun[[1]][1]
      out_df$rerun_se = final_rerun[[1]][2]
      out_df$rerun_pval = final_rerun[[1]][3]
      out_df$reruns = rerun_counter
      break
    }
  }

  # Output ----
  out$ContestSensitivity = out_df
  out$DroppedContests = final_rerun[[2]]
  out$ProfileKey = unique(cj_df[,c("profile_id", "profile")])
  out$RerunData = subset(cj_df, select = -c(profile, profile_opponent, influence))

  return(out)
}


#' Analyze Respondent Sensitivity
#'
#' @description Evaluates data at the respondent level to determine the sensitivity of AMCEs to the removal of influential respondents.
#'
#' @param fit.lm The linear model object estimated with lm() to be replicated.
#' @param segroup Vector of variable to group standard errors.
#' @param var_interest String name of the variable of analysis, (the target AMCE to analyze the sensitivity).
#' @param target Target string, either "sign" or "significance". Default is "sign".
#' @param dropped_resp_list Logical indicating whether to return the list of dropped respondents. Default is FALSE.
#'
#' @return If `dropped_resp_list=FALSE` (default), returns a data frame containing the sensitivity analysis results, including original estimates, the number of respondents dropped, and rerun estimates.
#' If `dropped_resp_list=TRUE`, returns a list containing:
#' \describe{
#'   \item{out_df}{The sensitivity analysis results data frame.}
#'   \item{DroppedRespondents}{A vector of the specific respondent IDs that were dropped.}
#' }
#' @export
AnalyzeRespondentSensitivity = function(fit.lm, segroup, var_interest, target = "sign",
                                        dropped_resp_list=FALSE){

  out_df = data.frame(param_name = var_interest)
  out_df$target = target

  # Get model coefficient and robust standard error----
  dat = fit.lm$model
  weight = fit.lm$weights
  c = colnames(fit.lm$model)
  i = 1
  for(j in c){
    if(grepl(" ", j)){
      c[i] = paste0("`", j, "`")}else if(grepl(')', j)){
        c = c[-i]
      }
    i = i + 1
  }
  formula_ = as.formula(paste0(c(c[1], paste0(c[2:length(c)], collapse="+")), collapse = "~"))
  est = estimatr::lm_robust(formula_, data = dat, clusters=segroup, weights = weight)

  model_coef_ = est$coefficients[var_interest]
  out_df$model_coef = model_coef_

  model_se = est$std.error[var_interest]
  out_df$model_se = model_se

  model_p = est$p.value[var_interest]
  out_df$model_p = model_p
  model_ = c(model_coef_, model_se, model_p)

  n_resp = length(unique(segroup))
  out_df$n_respondent = n_resp

  # Get respondent influences via GetRespondentInfluences() ----
  RespInfl = GetRespondentInfluences(fit.lm = fit.lm, segroup = segroup, var_interest = var_interest,
                                     target = target, callRerun=TRUE)

  df = RespInfl[[1]]
  drop_neg_inf = RespInfl[[2]]
  Delta = RespInfl[[3]]

  out_df$total_infl = sum(df$resp_infl)

  if (!drop_neg_inf){
    out_df['median_infl'] = median(df$resp_infl)
    out_df['n_pos_infl'] = sum(df$resp_infl>0)
    out_df['n_neg_infl'] = sum(df$resp_infl<0)
  } else{
    out_df['median_infl'] = -median(df$resp_infl)
    out_df['n_pos_infl'] = sum(df$resp_infl<0)
    out_df['n_neg_infl'] = sum(df$resp_infl>0)
  }

  resp_infl = sort(df$resp_infl, decreasing = T)
  cumulative_resp_infl = cumsum(resp_infl)

  if(sum(cumulative_resp_infl > Delta) > 0){
    upper_bound_n_dropped = which(cumsum(cumulative_resp_infl > Delta) == 1)
    v = rerun_lmrobust(ndrop = upper_bound_n_dropped, infl_df = df, formula_=formula_, dat=dat,
                       segroup=segroup, weight_=weight, var_interest = var_interest)

    not_reversed = !reversed(target = target, rerun = v[[1]], model = model_)

    if(not_reversed){
      upper_bound_n_dropped = upper_bound_n_dropped + 10
      v = rerun_lmrobust(ndrop = upper_bound_n_dropped, infl_df = df, formula_=formula_, dat=dat,
                         segroup=segroup, weight_=weight, var_interest = var_interest)

      not_reversed = !reversed(target = target, rerun = v[[1]], model = model_)
      if(not_reversed){
        upper_bound_n_dropped = upper_bound_n_dropped + 10
      }
    }
    out_df$n_drop_auto = upper_bound_n_dropped

    if(upper_bound_n_dropped == 1){
      out_df$n_drop_auto = upper_bound_n_dropped
      out_df$n_drop = upper_bound_n_dropped
      out_df$rerun_coef = v[[1]][1]
      out_df$rerun_se = v[[1]][2]
      out_df$rerun_pval = v[[1]][3]
      out_df$reruns = 1

      df_ordered =  df[order(df$resp_infl, decreasing = T), ]
      resp_dropped = df_ordered[1, ]$respondent

      if(dropped_resp_list){
        return(list(out_df, DroppedRespondents=resp_dropped))
      } else {
        return(out_df)
      }
    }

  } else {
    out_df$n_drop_auto = NA
    upper_bound_n_dropped = sum(resp_infl>0)
  }

  # RERUNS
  rerun_counter = 0
  s = seq(from = upper_bound_n_dropped-1, to = 1, by=-1)

  for(i in s){
    rerun_out = rerun_lmrobust(ndrop = i, infl_df = df, formula_=formula_, dat=dat,
                               segroup=segroup, weight_=weight, var_interest = var_interest)
    rerun_counter = rerun_counter + 1

    if(reversed(target = target, rerun = rerun_out[[1]], model = model_)){
      last_ndrop = i

      out_df$n_drop = last_ndrop
      out_df$rerun_coef = rerun_out[[1]][1]
      out_df$rerun_se = rerun_out[[1]][2]
      out_df$rerun_pval = rerun_out[[1]][3]
      out_df$reruns = rerun_counter

    } else {
      out_df$n_drop = i+1

      rerun_out = rerun_lmrobust(ndrop = i+1, infl_df = df, formula_=formula_, dat=dat,
                                 segroup=segroup, weight_=weight, var_interest = var_interest)
      rerun_counter = rerun_counter + 1

      out_df$rerun_coef = rerun_out[[1]][1]
      out_df$rerun_se = rerun_out[[1]][2]
      out_df$rerun_pval = rerun_out[[1]][3]
      out_df$reruns = rerun_counter

      break
    }
  }

  if(dropped_resp_list){
    return(list(RespondentSensitivity=out_df,
                DroppedRespondents=rerun_out[[2]]))
  } else {
    return(out_df)
  }
}







