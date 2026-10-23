source("00_config.R")
z <- readRDS(file.path(run_dir,"prepared.rds")); stopifnot(identical(cfg,z$cfg))
lm_wf <- workflow() %>% add_recipe(z$recipe) %>% add_model(linear_reg() %>% set_engine("lm"))
xgb_wf <- workflow() %>% add_recipe(z$recipe) %>% add_model(
  boost_tree(trees=tune(),min_n=tune(),tree_depth=tune(),learn_rate=tune(),loss_reduction=tune()) %>%
    set_engine("xgboost",nthread=1,verbosity=0) %>% set_mode("regression"))
set.seed(cfg$seed_grid)
grid <- dials::grid_space_filling(x=list(trees=dials::trees(c(500L,1800L)),
  min_n=dials::min_n(c(5L,30L)),tree_depth=dials::tree_depth(c(2L,8L)),
  learn_rate=dials::learn_rate(c(-3,-.5)),loss_reduction=dials::loss_reduction(c(-6,0))),size=cfg$grid_size)
write_table(grid,"tuning_grid.csv")
set.seed(cfg$seed_fit)
lm_cv <- fit_resamples(lm_wf,resamples=z$folds,metrics=metric_set(rmse,mae,rsq),
                      control=control_resamples(save_pred=TRUE,allow_par=FALSE))
set.seed(cfg$seed_fit)
xgb_cv <- tune_grid(xgb_wf,resamples=z$folds,grid=grid,metrics=metric_set(rmse,mae,rsq),
                   control=control_grid(save_pred=TRUE,verbose=TRUE,allow_par=FALSE))
write_table(collect_notes(xgb_cv),"tuning_notes.csv")
met <- collect_metrics(xgb_cv) %>% filter(.metric=="rmse")
if (any(met$n!=nrow(z$folds)) || any(!is.finite(met$mean))) stop("Incomplete tuning; inspect tuning_notes.csv.")
lm_met <- collect_metrics(lm_cv)
if (any(lm_met$n!=nrow(z$folds)) || any(!is.finite(lm_met$mean))) stop("Incomplete linear CV.")
best <- select_best(xgb_cv,metric="rmse")
write_table(best,"best_hyperparameters.csv")
write_table(bind_rows(collect_metrics(lm_cv) %>% mutate(model="Linear"),
                     collect_metrics(xgb_cv) %>% mutate(model="XGBoost")),"cv_log_metrics.csv")
set.seed(cfg$seed_fit)
fits <- list(Linear=fit(lm_wf,data=z$training),
             XGBoost=fit(finalize_workflow(xgb_wf,best),data=z$training))
saveRDS(list(fits=fits,lm_wf=lm_wf,xgb_wf=finalize_workflow(xgb_wf,best),
 best=best,lm_cv=lm_cv,xgb_cv=xgb_cv,signature=z$signature),file.path(run_dir,"models","fits.rds"))
