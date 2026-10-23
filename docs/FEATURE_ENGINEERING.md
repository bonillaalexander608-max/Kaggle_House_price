# Current corrected feature processing

The corrected pipeline retains the original feature ideas but learns numerical medians, categorical mappings, scaling and QR rank filtering within each fitting partition. OverallCond_grupo is categorical. OLS and FGLS receive the same encoded columns. See `analysis/House_Prices.Rmd` and `R/revised_analysis.R` for the implemented formulas and `reports/revised/model_features.csv` for the fitted columns. No skipped selection step is used.

The following section documents historical variants, not the corrected runtime:

# Feature engineering present in the supplied work

| Feature | Original construction | Scope |
|---|---|---|
| `Age_House` / `Age_house` | `YrSold - YearBuilt` | Notebook and model scripts |
| `Total_porch` | `OpenPorchSF + EnclosedPorch + ScreenPorch + 3SsnPorch` | Notebook and model recipes |
| `Has_porch` / `has_porch` | Indicator that total porch area is positive | EDA and some recipes |
| `TotalBath` | `BsmtFullBath + FullBath + 0.5*BsmtHalfBath + 0.5*HalfBath` | Notebook and model recipes |
| `OverallCond_grupo` | 1 if OverallCond ≤4; 2 if ≤7; 3 otherwise | EDA and model recipes |
| `has_pool` | Indicator `PoolArea > 0` | Notebook and later recipes |
| `has_misc` | Indicator `MiscVal > 0` | Notebook and later recipes |
| `has_fireplaces` | Indicator `Fireplaces > 0` | Notebook and later recipes |
| `has_masvnrarea` and spelling variants | Indicator `MasVnrArea > 0` | Notebook and later recipes |
| `log(SalePrice)` | Natural-log target; predictions/interval endpoints mapped back with exp | Model fits |
| `log(LotArea)` | Natural-log lot area | Later recipes |

Names vary across files; these are not additional independent predictors. EDA also compares raw-feature correlations, categorical ANOVA, pairwise chi-square tests and single-variable sums of squares. The five selected categorical predictors are Neighborhood, ExterQual, BsmtQual, KitchenQual and GarageFinish.

Raw first/second floor fields are renamed `Flr1_sl` and `Flr2_SF` and later removed. Recipes remove Id, redundant component fields and other manually selected predictors. Some variants apply correlation filtering at 0.8; others do not. Rare Neighborhood categories are pooled at 0.005 in later scripts, with novel/unknown levels and dummy encoding. Normalization selectors also vary by script.

Missing numeric values are replaced with training-file medians and character NAs with `None`, after train/test concatenation and before the internal split. These operations are preserved as part of the original implementation; they are not described as fold-specific imputation.

**Code versus narrative:** `OverallCond_grupo` is numeric in the displayed recipe; the prose says dummy coding, but the code does not implement that conversion. Not every constructed feature survives every recipe. `Total_porch` is removed after deriving its indicator. The notebook's WLS recipe differs from the linear feature-engineered recipe and uses the original columns; it must not be described as an identical-feature comparison.
