#' Plot CDF of Respondent Influences
#'
#' @description Plots the cumulative distribution function (CDF) of respondent influences on either the sign or significance of the target AMCE. Highlights the dropped respondents and the median respondent.
#'
#' @param fit.lm The linear model object estimated with lm() to be replicated.
#' @param segroup Vector of variables to group standard errors.
#' @param var_interest String name of the variable of analysis (the target AMCE).
#' @param target String, either "sign" or "significance". Default is "sign".
#' @param ndrop Optional integer indicating the number of respondents dropped to be highlighted in red.
#' @param main Optional string for the main title of the plot.
#'
#' @return A data frame of respondents and their calculated influences, sorted in decreasing order.
#' @export
plot_cdf_respondent_influences = function(fit.lm, segroup, var_interest, target = "sign", ndrop=NULL, main = NULL){

  # Model coefficient and robust standard error
  dat = fit.lm$model
  weight = fit.lm$weights
  c = colnames(fit.lm$model)
  i = 1
  for(j in c){
    if(grepl(" ", j)){
      c[i] = paste0("`", j, "`")
    } else if(grepl(')', j)){
      c = c[-i]
    }
    i = i + 1
  }

  formula_ = as.formula(paste0(c(c[1], paste0(c[2:length(c)], collapse="+")), collapse = "~"))
  est = estimatr::lm_robust(formula_, data = dat, clusters=segroup, weights = weight)

  model_coef_ = est$coefficients[var_interest]
  model_se = est$std.error[var_interest]

  # Calculate respondent influences
  RespInfl = GetRespondentInfluences(fit.lm = fit.lm, segroup = segroup, var_interest = var_interest,
                                     target = target, model_coef_ = model_coef_, model_se = model_se)

  df = RespInfl[[1]]
  drop_neg_inf = RespInfl[[2]]

  # Plot Setup
  df_ordered = df[order(df$resp_infl, decreasing = T), ]

  x = sort(df_ordered$resp_infl)
  y = as.vector(1:nrow(df)/nrow(df))

  if(target=="sign"){
    x_lab = "Respondent Influences on the Sign of AMCE"
  } else {
    x_lab = "Respondent Influences on the Significance of AMCE"
  }

  y_lab = "Fn(Influences)"
  y_lim = seq(from=0, to=1, by=0.2)

  # Base Plot
  plot(x, y, xlab=x_lab, ylab=y_lab, axes=F, main = main,
       xlim=1.2*c(min(x), max(x)))

  # Color dropped respondents if the number is provided
  if(!is.null(ndrop)){
    if(drop_neg_inf){
      l = 1
      u = ndrop
      points(x[l:u], y[l:u], col="red")
      abline(h=u/nrow(df), col="red", lwd=1.2, lty=2)
    } else{
      l = nrow(df)-ndrop
      u = nrow(df)
      points(x[l:u], y[l:u], col="red")
      abline(h=l/u, col="red", lwd=1.2, lty=2)
    }
  }

  # Color median respondent
  m = nrow(df)/2
  points(x[m], y[m], col="green", pch=16, cex=1.2)

  # Add axes and reference lines
  axis(2, at = y_lim)
  axis(1)
  abline(h=0.5, col="blue", lwd=1.2, lty=2)
  abline(v=0, col="red", lwd=1.2, lty=2)
  grid(nx = 4, ny = 4)
  #return(df_ordered)
}
