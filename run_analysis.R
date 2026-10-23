# Run from repository root; no third-party packages or original interactive objects needed.
source('R/revised_analysis.R')
result<-run_house_analysis()
print(result$cv_summary)
print(result$holdout_metrics)
print(result$interval_summary)
source('R/write_report.R')
write_house_report()
