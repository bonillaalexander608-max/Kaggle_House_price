source("00_config.R")
z <- readRDS(file.path(run_dir,"prepared.rds")); s <- readRDS(file.path(run_dir,"models","fits.rds"))
stopifnot(identical(s$signature,z$signature),identical(cfg,z$cfg))
# Refit only after the evaluation specification is frozen. No further holdout selection.
set.seed(cfg$seed_fit)
lm_final <- fit(s$lm_wf,data=z$train)
set.seed(cfg$seed_fit)
xgb_final <- fit(s$xgb_wf,data=z$train)
a <- exp(predict(lm_final,new_data=z$test)$.pred)
b <- exp(predict(xgb_final,new_data=z$test)$.pred)
preds <- list(Linear=a,XGBoost=b,Blend=cfg$linear_weight*a+(1-cfg$linear_weight)*b)
for (m in names(preds)) {
 output <- tibble(Id=z$test$Id,SalePrice=preds[[m]])
 stopifnot(nrow(output)==1459L,!anyDuplicated(output$Id),all(is.finite(output$SalePrice)),all(output$SalePrice>0))
 write_csv(output,file.path(run_dir,paste0("submission_",tolower(m),".csv")))
}
saveRDS(list(Linear=lm_final,XGBoost=xgb_final),file.path(run_dir,"models","full_data_fits.rds"))
