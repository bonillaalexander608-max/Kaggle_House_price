# Current and historical models

The current executed comparison is OLS versus feasible GLS with shared features. Ten-fold CV also evaluates a training-only area restriction; holdout rows are never excluded. A separate fixed OLS proper-training model supplies split-conformal intervals. Fresh exported results are in `reports/revised/`. Original XGBoost/blend branches below have not been rerun under common corrected validation and have no revised score here.

# Model branches in the supplied files

| Branch | Source | What is present |
|---|---|---|
| Linear regression | Rmd and houseprice.R | log-price model, engineered features, diagnostics and prediction intervals |
| Filtered linear | houseprice.R; linear_and_xgboost.R | GrLivArea <3500; residual/Cook exclusions in different variants |
| WLS | Rmd | initial residual weights `1/(abs(residual)+1e-6)`, lm case weights, internal-test diagnostics and intervals |
| Regularized linear / elastic-net experiments | houseprice.R | glmnet fits, 15-fold resampling, penalty/mixture grid; no new results reconstructed |
| XGBoost A | linear_and_xgboost.R | trees 842, min_n 20, depth 5, learning rate 0.234, loss_reduction 1e-10 |
| XGBoost B | xgboost_experiments.R | trees 1684, min_n 14, depth 15, learning rate 0.0280, loss_reduction 1.06e-7 |
| XGBoost tuning | both XGBoost scripts | trees/depth/min_n/loss_reduction/learn_rate, 5 folds and grid 20 |
| Dollar-price blend | linear_and_xgboost.R | 60% Linear / 40% XGBoost; another export 60.55% / 39.45%; exploratory weight scan 0.50–0.80 |

These are distinct experiments, not a single selected final configuration. The exploratory files refer to objects created elsewhere, so a file's execution order matters. No new optimal weights, CV design or parameter set is introduced by this repository presentation.
