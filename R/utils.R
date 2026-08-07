# Internal helper function to wrap estimatr::lm_robust for sensitivity loops
rerun_lmrobust = function(ndrop, infl_df, formula_, dat, var_interest,
                          analysis = c("respondent", "contest"), segroup=NULL,
                          weight_=NULL){
  #This function acts as a wrapper for the estimatr::lm_robust function.
  #It drops a specified number of highly influential entities (respondents, or contests),
  #recalculates the model, and returns a list containing:

  #(1) a vector of rerun_coef, rerun_se and p-value
  #(2) vector of dropped respondents, or contests depending on analysis.'

  analysis = match.arg(analysis)

  if(analysis == "respondent"){
    df_ordered = infl_df[order(infl_df$resp_infl, decreasing = T), ]
    dropped = df_ordered[1:ndrop, ]$respondent
    resp_dropped_indices = which(segroup %in% dropped)
    estt = estimatr::lm_robust(formula_, data = dat[-resp_dropped_indices, ],
                               clusters= segroup[-resp_dropped_indices],
                               weights = weight_[-resp_dropped_indices])
  } else if (analysis == "contest"){
    df_ordered = infl_df[order(infl_df$contest_infl, decreasing = T), ]
    dropped = df_ordered[1:ndrop, ]$contest_id
    contests = dat$contest_id
    contest_dropped_indices = which(contests %in% dropped)

    df = dat[-contest_dropped_indices, ]
    estt = estimatr::lm_robust(formula_, data = df,
                               clusters = respondent_id, weights = weight)
  }

  coef_ = estt$coefficients[var_interest]
  se_= estt$std.error[var_interest]
  p_ = estt$p.value[var_interest]

  return(list(c(coef_, se_, p_), dropped))
}

# Internal helper function to check if sign/significance is reversed
reversed = function(target, rerun, model){
  #Compares a rerun model against an original model to check if the target metric has flipped.
  #Returns TRUE if sign/significance is reversed; FALSE otherwise.

  m_coef = as.numeric(model[1])
  m_pval = as.numeric(model[3])
  r_coef = as.numeric(rerun[1])
  r_pval = as.numeric(rerun[3])


  if(target == "sign"){
    return(!(sign(r_coef) == sign(m_coef)))
  }else{
    alpha = 0.05 # significance level
    model_sig = m_pval < alpha
    rerun_sig = r_pval < alpha
    return(!(model_sig == rerun_sig))
  }
}

