
<!-- README.md is generated from README.Rmd. Please edit that file -->

# ConjointSensitivity

<!-- badges: start -->

<!-- badges: end -->

This package is developed to evaluate the robustness of conjoint
analysis results to the removal of small fractions of respondents and
experimentally generated unique contests.

Our package is built on `zaminfluence` to calculate influence scores and
detect the most influential respondents and contests in conjoint
designs.

We provide a simple example to demonstrate how to use
`ConjointSensitivity` using the replication data for the non-partisan
YouGov experiment in Kirkland and Coppock (2018).

## References

- **zaminfluence Package & Methodology:** Broderick, T., Giordano, R., &
  Meager, R. (2020). *An Automatic Finite-Sample Robustness Metric: When
  Can Dropping a Little Data Make a Big Difference?*

- **Kirkland and Coppock (2018) Data:** Kirkland, P. A., & Coppock, A.
  (2018). *Candidate choice without party labels: new insights from
  conjoint survey experiments*. Political Behavior, 40, 571–591.

## Citation

If you use `ConjointSensitivity` in your research, please cite our
paper:

Abramson, S., & Zafer, B. (2026) *Do Voters Prefer Women and Young
Candidates? Re-evaluating Evidence from Conjoint Experiments*

## Installation

You can install the development version of ConjointSensitivity like so:

``` r
# install.packages("devtools")
devtools::install_github("zfrb/ConjointSensitivity")
```

## Quickstart

This example demonstrates how to use ConjointSensitivity using the
replication data for the non-partisan YouGov experiment in Kirkland and
Coppock (2018).

``` r
library(ConjointSensitivity)
library(dplyr, quietly = T, warn.conflicts = FALSE)
library(torch)
library(purrr)

# Load the conjoint dataset
df <- read.csv("tests/testthat/testdata_KirklandCoppock_nonpartisan_yougov.csv")
```

### 1. Respondent Sensitivity

``` r
# Fit the base linear model
df$Age = as.character(df$Age)  # factor() is not allowed in formula
fit.lm <- lm(
  as.formula(win ~ cand_female + Age + Race + Job + Political), 
  data = df, 
  weights = weight, 
  x = TRUE, 
  y = TRUE
)

# Run the respondent-level analysis
respondent_results <- AnalyzeRespondentSensitivity(
  fit.lm = fit.lm, 
  segroup = df$caseid, 
  var_interest = "cand_female", 
  target = "sign", 
  dropped_resp_list = TRUE
)

# View main results 
respondent_results$RespondentSensitivity
#>    param_name target model_coef   model_se    model_p n_respondent   total_infl
#> 1 cand_female   sign 0.03875656 0.01932379 0.04707456         1146 -1.23122e-15
#>     median_infl n_pos_infl n_neg_infl n_drop_auto n_drop   rerun_coef
#> 1 -4.175677e-06        555        591          16     14 -0.001237848
#>     rerun_se rerun_pval reruns
#> 1 0.01630143  0.9395925      4

# View dropped respondents  
respondent_results$DroppedRespondents
#>  [1]  845 1133 1095 1157 1109  819  306   43  932  503  630  916  517  107
```

#### Visualising the Respondent Influences CDF

``` r
plot_cdf_respondent_influences(fit.lm = fit.lm, segroup = df$caseid, var_interest = "cand_female", ndrop = 14)
```

<img src="man/figures/README-plot-1.png" width="100%" />

### 2.Contest Sensitivity

``` r
contest_results <- AnalyzeContestSensitivity(
  formula = as.formula(win ~ cand_female + Age + Race + Job + Political), 
  data = as.data.frame(df), 
  respondent_id = "caseid", 
  contest_no = "contest_no", 
  var_interest = "cand_female", 
  target = "sign", 
  weights = "weight"
)

# View main results
contest_results$ContestSensitivity
#>    param_name target model_coef   model_se    model_p    total_infl n_contest
#> 1 cand_female   sign 0.03875656 0.01932379 0.04707456 -1.248716e-15      2887
#>     median_infl n_pos_infl n_neg_infl n_drop_auto n_drop   rerun_coef rerun_se
#> 1 -1.698448e-06       1416       1471          23     22 -0.001444463 0.016424
#>   rerun_pval reruns
#> 1  0.9300392      3

# View dropped contests 
contest_results$DroppedContests
#>  [1] "201-870"  "398-757"  "350-664"  "530-1246" "28-1138"  "546-1214"
#>  [7] "457-1236" "374-1035" "149-1036" "474-1135" "95-978"   "190-1012"
#> [13] "201-773"  "395-951"  "634-706"  "332-766"  "600-1322" "220-1266"
#> [19] "103-937"  "52-1001"  "134-812"  "57-954"

# View the mapping from profile attributes to contest ids.
head(contest_results$ProfileKey)
#>   profile_id                                           profile
#> 1        584       0-65-Hispanic-Attorney-SchoolBoardPresident
#> 2        552             0-65-Black-Educator-CityCouncilMember
#> 3        291 0-45-Hispanic-Stay-at-HomeDad/Mom-StateLegislator
#> 4        433       0-55-Hispanic-Electrician-CityCouncilMember
#> 5        762            1-35-Hispanic-Educator-StateLegislator
#> 6        808   1-35-White-Electrician-RepresentativeinCongress
```
