# Verification of the external review

Reviewed against commit aad1d298b0aaee50fa72d49b7204c72c10d62b0a, including all three original R scripts, the Rmd, saved HTML outputs and existing documentation. The review document had explicitly excluded those scripts and outputs. Corrections below distinguish confirmed code problems from unverified explanations.

| Review claim | Verification and action |
|---|---|
| The Rmd claims a GrLivArea <4000 filter but does not execute it | Confirmed. Removed the unsupported claim from the current notebook. The revised run compares no restriction against a <4000 **training-only** restriction in identical CV assessment folds; holdout houses are retained. Other original scripts actually use <3500. No filter is presented as universally correct. |
| OLS and WLS change recipes as well as weights | Confirmed. The original WLS includes raw variables and Id omitted by the OLS recipe. A new common feature matrix now feeds both OLS and FGLS. No causal attribution of historical metric differences to weights is justified. |
| Reciprocal absolute residual weights do not estimate conditional inverse variance | Confirmed. The corrected FGLS estimates log squared residuals as a function of OLS fitted log price, then predicts positive variance weights for new houses. This is a working variance model, not a guarantee of superior accuracy or efficient inference. |
| step_select(skip=TRUE) is skipped by bake(new_data=...) | Confirmed by the documented recipe semantics. This can reintroduce columns into the separate preliminary fit. The corrected pipeline selects predictors explicitly and uses the same fitted transformation for training and prediction; no skipped selection step remains. |
| Weighted intervals assume constant future variance when weights are omitted | Confirmed warning in the saved HTML. Revised FGLS passes predicted new-observation weights to predict.lm. Its intervals remain approximate because variance-model estimation uncertainty and possible misspecification are not fully accounted for. |
| All original log intervals have identical width | Incorrect. Even with a common future-error variance, coefficient uncertainty depends on x0 and can change width. A constant future variance is not a constant total predictive variance. No empirical doubling of width or residual sigma is established by the review. |
| 98.98% coverage proves correct calibration | The original notebook's guarantee is unsupported. Coverage exceeds 95%, but one observed percentage alone does not prove overcoverage in the population. Interval width, sample size and coverage uncertainty matter. The historical figure has 98.98%; the separate in-sample Excel has 96.01%. They are distinct artifacts. |
| Dollar-scale residuals establish heteroscedasticity of the log model | Incorrect inference. The original diagnostic was on dollars. Revised diagnostics use training residuals on log price. Dollar errors are retained as performance measures, not as a direct test of log-error homoscedasticity. |
| Imputation and variable screening precede the internal split | Confirmed. Revised numeric medians, categorical mappings, scaling and rank filtering are learned only from each analysis partition. The feature set is inherited from historically explored data, so this remains post hoc internal validation, not a pristine external test. |
| The original repo has no Kaggle submission code | Too broad. The reviewed Rmd does not produce one, but source/houseprice.R and source/linear_and_xgboost.R do, as does source/xgboost_experiments.R. The repository previously lacked the exported submission file. The revised run creates a fresh submission CSV; it is not submitted to Kaggle and has no claimed public score. |
| Conclusion III is empty | Incorrect for the actual Rmd: a paragraph is present, but its 0.918/perfect-coverage claims are not supported by the saved output. Rewritten from the revised run instead. |
| The suggested conformal quantile is finite-sample valid as written | Needs correction. R quantile defaults to interpolating type=7. The revised code uses the exact kth sorted score, k=ceil((m+1)(1-alpha)); if k>m it returns an unbounded interval. The OLS family and no-area-filter policy for conformal are fixed independently of CV choices; its proper fit is never refitted on calibration data. |

Additional confirmed narrative mismatches: Electrical is replaced with None rather than a median/mode; OverallCond_grupo is numeric despite prose promising dummies; the point-biserial calculation uses unlogged SalePrice; add1 output is sorted by Sum of Sq rather than AIC; the NA table inspects the unimputed frame; the data do not validate Nicaragua valuation. These descriptions are replaced in the current notebook. A sample size near 290 does not make a Lilliefors rejection inevitable, and an assumed sigma or interval-width multiplier cannot be recovered from the review alone. Missingness percentages alone do not establish MNAR, marginal price non-normality does not prove that a log transform is required, and non-normal residuals alone do not prove coefficient bias.

## Source-script findings beyond the external review

Both XGBoost branches fit xgb_fit on Train_filtrado and later score Test_split drawn from that data, so that evaluation is not independent. Several blends use interactive objects and scan weights on reused data. The original <3500/residual/Cook exclusions also define different fitting samples. These files are preserved in source/ as historical experiments; no XGBoost superiority or revised blend score is claimed without a new common validation run. They are not part of the corrected OLS/FGLS performance table.

## Sources for the statistical corrections

- R stats, predict.lm: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/predict.lm.html
- recipes, step_select and skip: https://recipes.tidymodels.org/reference/step_select.html
- Lei et al., Distribution-Free Predictive Inference for Regression: https://arxiv.org/abs/1604.04173

The revised computation uses base R to make the shared design matrix, variance weights and interval calculations directly inspectable. Original tidymodels code remains unchanged in source/ and analysis/House_Prices_legacy.Rmd.
