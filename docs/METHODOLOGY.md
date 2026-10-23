# Methodology

## Evaluation target

The outcome is the natural logarithm of SalePrice. Primary metric: sqrt(mean((log(observed) - predicted_log)^2)). Dollar MAE/RMSE and predictive R² are secondary. Squared correlation is reported by tidymodels CV as `rsq`; it is not the same as 1 − SSE/SST. Exponentiated log predictions are not automatically unbiased estimates of mean price in dollars; no smearing correction is applied.

## Validation

An 80/20 split of labelled houses is followed by five-fold CV in training, shared by linear and XGBoost pipelines. All learned imputation, encoding and normalization occur inside resampling recipes. Twenty XGBoost configurations are selected by mean CV RMSE on the log scale. Split/fold/grid/fit/bootstrap seeds are explicit in config. No early stopping. Sequential, single-thread XGBoost limits resource usage.

The blend has a fixed 60% linear / 40% XGBoost weight on the dollar scale, inherited from the original exploratory scripts. It is not claimed optimal. Test labels from Kaggle are unavailable locally; local validation is not a leaderboard score. The dataset has already been explored, so a new split is an exploratory reassessment, not untouched external validation.

Feature selection is fixed from the original experiment: numeric housing features plus neighbourhood, exterior/basement/kitchen quality, garage finish and categorical MSSubClass. Engineered age, bathroom and porch variables are retained. No row is deleted based on residuals, Cook's distance, or living area. The revised results will therefore differ from old filtered experiments. A generic missing category does not fully resolve structural absence versus unknown information; this is a documented simplification.

## Intervals

The script resamples held-out houses with replacement 2000 times. The same sampled indices are used for every model. Percentile intervals use quantiles 0.025 and 0.975. Error improvement is reference Linear minus candidate; predictive R² improvement is candidate minus Linear. Estimates are calculated on the original held-out observations. Models are not refit during the bootstrap. Intervals assume an adequate independent-house sampling approximation; spatial/temporal dependence and distribution shift are not accounted for. They are marginal exploratory intervals without multiplicity correction. An interval covering zero does not establish equivalence.

These confidence intervals describe uncertainty in model metrics/differences. They are not prediction intervals for individual houses. No revised house-level prediction-interval coverage is claimed.

## Limits

Performance on Ames data does not transfer automatically to Nicaragua or another market. Non-normal errors alone do not establish biased OLS coefficients. WLS requires a justified variance/weight model; inverse absolute fitted residuals are not treated as a validated replacement. The revised baseline omits the experimental WLS branch pending proper validation.

No model training was run during repository preparation because R is unavailable in that environment. Execute the pipeline and inspect tuning notes, predictions and metrics before reporting revised performance.
