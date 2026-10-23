# Historical source material

The original R/Rmd files remain byte-for-byte copies of the supplied sources; names are standardized for links. `original_render.log` and `reports/original_report.html` are historical outputs containing known methodological/narrative errors. `analysis/House_Prices_legacy.Rmd` preserves the prior portable notebook. They are retained for traceability, not recommended as the current validated analysis.

The corrected principal notebook is `analysis/House_Prices.Rmd`, backed by `R/revised_analysis.R`. Run `Rscript run_analysis.R` from the root. No original source script is silently used as a standalone validated pipeline. XGBoost/blend scripts have overlapping fit/evaluation data and interactive dependencies; their original scores must not be treated as revised holdout performance.

`install_legacy_dependencies.R` preserves the previous installer for those optional historical experiments. `.RData` and console history are not published.
