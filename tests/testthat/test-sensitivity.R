library(torch)
library(purrr)
# tests/testthat/test-sensitivity.R

test_that("AnalyzeContestSensitivity works with KC replication data", {

  # Load the pre-configured arguments list
  df = read.csv("testdata_KirklandCoppock_nonpartisan_yougov.csv")

  # Run the contest sensitivity function
  result = AnalyzeContestSensitivity(
    formula = as.formula(win ~ cand_female + Age + Race + Job + Political),
    data = as.data.frame(df),
    respondent_id = "caseid",
    contest_no = "contest_no",
    var_interest = "cand_female",
    target = "sign",
    weights = "weight"
  )
})

test_that("AnalyzeRespondentSensitivity works with KC replication data", {

  # Load the pre-configured arguments list
  df = read.csv("testdata_KirklandCoppock_nonpartisan_yougov.csv")

  fit.lm = lm(as.formula(win ~ cand_female + Age + Race + Job + Political),
              data = df, weights = weight, x = T, y = T)

  # Run the respondent sensitivity function
  result = AnalyzeRespondentSensitivity(
    fit.lm = fit.lm,
    segroup = df$caseid,
    var_interest = "cand_female",
    target = "sign",
    dropped_resp_list = TRUE
  )

})
