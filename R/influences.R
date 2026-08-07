GetRespondentInfluences = function(fit.lm, segroup, var_interest, target,
                                   model_coef_=NULL, model_se=NULL, callRerun=F){

  # ARGUMENTS:
  # * fit.lm: lm() object of the regression model to be replicated.
  # * segroup: Vector of variable to group standard errors if standard errors are clustered.
  # * var_interest: string. Name of variable of analysis.
  # * target: "sign" or "significance".
  # * model_coef_ and model_se: Optional arguments for coefficient and standard error of the variable of interest.
  #If not provided, function will retrieve values using fit.lm, segroup and var_interest.
  # * callRerun: TRUE if the function is called by RerunRespondentDrop(); Should be FALSE otherwise.

  # OUTPUT: list.
  #  [[1]]: dataframe. of respondents and respondent influences
  #  [[2]]: logical. True if the process will drop negative influences.
  #  [[3]]: numeric. Delta value


  if(!is.numeric(model_coef_)){

    # Get model coefficient and robust standard error####
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
    model_se = est$std.error[var_interest]
    model_p = est$p.value[var_interest]
  }

  # Calculate influence scores of data points for var_interest using zaminfluence package----
  model_grads = ComputeModelInfluence(fit.lm, se_group = segroup) %>% AppendTargetRegressorInfluence(var_interest)     #names(coefficients(fit.lm)[2]))
  signals = GetInferenceSignals(model_grads)

  # Calculate Delta and determine which respondents to be dropped----
  if(target == "sign"){
    influences = signals[[var_interest]]$sign$qoi$infl
    drop_neg_inf = ifelse(model_coef_ < 0, TRUE, FALSE)
    Delta = abs(model_coef_)
  } else if(target == "significance"){
    influences = signals[[var_interest]]$sig$qoi$infl
    alpha = 0.05 # significance level
    t_sig = qnorm(1-alpha/2) # t value at alpha level
    moe = t_sig*model_se # margin of error
    Delta = abs(abs(model_coef_) - moe)   # delta

    if(model_p<alpha){
      drop_sign = sign(model_coef_)
    } else {
      drop_sign = -sign(model_coef_)}

    drop_neg_inf = ifelse(drop_sign==(-1), T, F)
  } else {
    stop("Wrong target. Target must be `sign` or `significance`.")
  }

  # Aggregate influences at respondent level----
  if(callRerun){
    if(drop_neg_inf){
      influences = (-1)*influences
    }
  }

  infl_resp_df = as.data.frame(influences)
  infl_resp_df$respondent = segroup
  infl_resp_df$influence = as.numeric(infl_resp_df$influence)

  #total influence by respondent
  df = infl_resp_df %>% group_by(respondent) %>% reframe(resp_infl = sum(influence))

  # Construct the output----
  Out = list()
  Out$df_resp_infl = df
  Out$`Negative Influences Dropped` = drop_neg_inf
  Out$Delta = Delta

  return(Out)
}



GetContestInfluences = function(formula, data, respondent_id, contest_no,
                                var_interest, target, weights, callRerun=TRUE){
  Out = list()
  # lm() model -----
  if(!is.null(weights)){
    w = as.vector(subset(data, select = weights))[[1]]
    data$weight = w
    fit.lm = lm(formula, data, weights=weight, x = T, y = T)
  } else {
    data$weight = 1
    fit.lm = lm(formula, data, weights=weight, x = T, y = T)}

  lm_df = fit.lm$model # model data
  if(nrow(lm_df) != nrow(data)){
    stop("Conjoint data should not have NAs.")
  }

  attr_ = attributes(fit.lm$terms)
  names_attr = names(attr_$dataClasses)
  yX = names_attr[!names_attr %in% "(weights)"]
  y = yX[1]
  X = yX[-1]

  cj_df = data[,c(respondent_id, contest_no)]
  colnames(cj_df) = c("respondent_id", "contest_no")
  cj_df = cbind(cj_df, lm_df[, c(y,X)])
  cj_df$weight = fit.lm$weights

  # profile id -----
  profile_key = vector()
  for(row in 1:nrow(cj_df)){
    cj_df[row, X] %>% as.matrix()%>%as.vector() -> values
    key = paste0(values, collapse = "-")
    key = str_remove_all(key, " ")
    profile_key[row] = key
  }
  cj_df$profile = profile_key
  cj_df$profile_id = as.numeric(interaction(cj_df$profile))

  # opponent's profile -----
  opponent_profile_key = vector()
  for(row in 1:nrow(cj_df)){
    resp_id = cj_df[row, "respondent_id"] %>% as.matrix()%>%as.character()
    contest = cj_df[row, "contest_no"] %>% as.matrix()%>%as.character()

    df_notrow = cj_df[-row, ]
    df_notrow[, "respondent_id"] = as.character(df_notrow[, "respondent_id"])
    df_notrow[, "contest_no"] = as.character(df_notrow[, "contest_no"])

    opponent_key = df_notrow[df_notrow[, "respondent_id"]==resp_id & df_notrow[, "contest_no"]==contest, ]$profile
    if (length(opponent_key) > 0){
      opponent_profile_key[row] = opponent_key
    } else {
      opponent_profile_key[row] = NA }
  }
  cj_df$profile_opponent = opponent_profile_key
  err = sum(is.na(opponent_profile_key))
  if(err>0){
    err_df = cj_df[is.na(cj_df$profile_opponent), ]
    m1 = "Error (3)"
    m2 = "NAs are generated in the opponent profile due to missing second observations for some contests."
    warning(m2, call. = FALSE)
    return(list(m1, m2, err_df))
  }
  # numeric profile ids
  cj_df$profile_id = as.numeric(interaction(cj_df$profile))
  cj_df$profile_opponent_id = as.numeric(interaction(cj_df$profile_opponent))

  # unique question key -----
  question_key = vector()
  for(row in 1:nrow(cj_df)){
    profile_match = sort(c(cj_df$profile_id[row], cj_df$profile_opponent_id[row]))
    key = paste0(profile_match, collapse = "-")
    question_key[row] = key
  }
  cj_df$contest_id = question_key

  # compute influences of data points -----
  cls = cj_df[,"respondent_id"]
  model_grads = ComputeModelInfluence(fit.lm, se_group = cls) %>% AppendTargetRegressorInfluence(var_interest)
  signals = GetInferenceSignals(model_grads)

  est = estimatr::lm_robust(formula, data, clusters=cls, weights = weight)
  model_coef = est$coefficients[var_interest]
  model_se = est$std.error[var_interest]
  model_p = est$p.value[var_interest]

  #####
  if(target=="sign"){
    influences = signals[[var_interest]]$sign$qoi$infl
    drop_neg_inf = ifelse(model_coef < 0, TRUE, FALSE)
    Delta = abs(model_coef)
  } else if(target=="significance"){
    influences = signals[[var_interest]]$sig$qoi$infl
    alpha = 0.05 # significance level
    t_sig = qnorm(1-alpha/2) # t value at alpha level
    moe = t_sig*model_se # margin of error
    Delta = abs(abs(model_coef) - moe)   # delta
    if(model_p<alpha){
      drop_sign = sign(model_coef)
    } else {
      drop_sign = -sign(model_coef)}

    drop_neg_inf = ifelse(drop_sign==(-1), T, F)
  } else {
    stop("Wrong target. Target must be `sign` or `significance`.")
  }

  if(callRerun){
    if(drop_neg_inf){
      influences = (-1)*influences
    }
  }
  cj_df$influence = influences

  # aggregate influences at contest level ------
  cols = c("contest_id", "influence")
  infl_df = cj_df[,cols]
  infl_df$influence = as.numeric(infl_df$influence)
  infl_df$count = 1
  df = infl_df %>% group_by(contest_id) %>% reframe(contest_infl = sum(influence),
                                                    contest_frequency = sum(count)/2)
  # output ----
  Out$df_influence$not_agg = infl_df
  Out$df_influence$contest = df

  Out$`Negative Influences Dropped` = drop_neg_inf
  Out$Delta = Delta
  Out$df_conjoint = cj_df
  Out$ConjointResults = est

  return(Out)
}


