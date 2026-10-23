# Recorded results and evaluation scope

The supplied HTML is the source of the following rounded printed results, not an unexecuted reimplementation:

| Model | Partition | RMSE (USD) | `rsq` | MAE (USD) |
|---|---|---:|---:|---:|
| Linear regression | Training | 26,096 | 0.883 | 16,265 |
| Linear regression | Internal test | 40,897 | 0.800 | 19,212 |
| Weighted least squares | Internal test | 50,837 | 0.756 | 18,195 |

`rsq` is the squared Pearson correlation returned by yardstick, not automatically predictive 1 − SSE/SST. The WLS result has lower MAE but higher RMSE and lower squared correlation than Linear in this saved run. It is not uniformly better. The notebook's narrative numbers 0.918 / 14,819 do not match these printed outputs; neither is substituted for the other. A verified XGBoost/blend metric export was not supplied, so no comparable numbers are invented for those branches.

## Two distinct prediction-interval artifacts

1. `reports/Intervalo_prediccion.xlsx`: 1,454 original rows with `.pred`, SalePrice, Upper, Lower, inside. Its structure and row count correspond to the training-prediction export in `houseprice.R` after the living-area filter. Recomputed coverage is 96.01% (1396/1454), mean width USD 93,483.35, median width USD 85,772.29. These are **in-sample artifact summaries**, not independent test coverage and not the WLS interval result. CSV and JSON summaries are provided without modifying the workbook.
2. `reports/figures/10_wls_prediction_intervals.png`: the saved HTML's WLS internal-test plot. Code calls `predict.lm(..., interval="prediction", level=0.95)` and exponentiates fit/lwr/upr. The saved figure displays 98.98% observed coverage. Raw WLS interval rows were not supplied separately, so this percentage is read from the figure rather than independently recalculated. The plot is retained; its nominal 95% is not a verified calibration guarantee.

For an unweighted log-linear model, the conventional individual prediction interval is

$$\hat y_0 \pm t_{n-p,0.975}s\sqrt{1+x_0^T(X^TX)^{-1}x_0},$$

on the log scale; exponentiating both endpoints gives a dollar interval. This differs from a confidence interval for the conditional mean, which omits the leading 1. The WLS expression needs a suitable new-observation variance as well as coefficient uncertainty; the unweighted expression is not asserted valid for the supplied weighted fit.

The HTML records warnings: `prediction from rank-deficient fit` and `Assuming constant prediction variance even though model fit is weighted`. The original WLS uses `1/(abs(residual)+1e-6)` weights and calls predict without a separately established future-observation variance model. The intervals are therefore documented as the original exploratory calculation, not certified 95% coverage. No conformal intervals or new bootstrap procedure have been added.

## Validation and diagnostics actually present

- The notebook sets seed 123 and makes an 80/20 internal split after shared preprocessing; predictors/target have already been explored.
- Some standalone scripts filter GrLivArea <3500; their residual/Cook-based exclusions and 10-/15-fold experiments are separate variants. The notebook prose mentions 4000 but does not implement that filter in its displayed preparation.
- XGBoost variants fit on `Train_filtrado` and later score `Test_split`, which can overlap the fit data; those scores are not treated as independent test performance.
- XGBoost tuning uses 5 folds, 20 candidates, seed 26 in the supplied scripts. The fixed parameter sets and blends are documented, without retraining or choosing a new winner.
- EDA includes normality tests, missingness, correlation and categorical screening. Cook's distance, residual plots and QQ plots are included. Non-normal residuals alone do not prove biased OLS coefficients, and missingness percentages do not establish MNAR.
- The data concern Ames, Iowa. Mentions of Nicaragua in the original prose do not establish geographic transfer.

No models were re-estimated during repository reformulation. Figures were extracted from the saved HTML and workbook statistics recomputed from its cells. Original sources and report remain available for traceability.
