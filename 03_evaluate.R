source("00_config.R")
z <- readRDS(file.path(run_dir,"prepared.rds")); s <- readRDS(file.path(run_dir,"models","fits.rds"))
stopifnot(identical(s$signature,z$signature),identical(cfg,z$cfg))
p_lm <- predict(s$fits$Linear,new_data=z$holdout)$.pred
p_xgb <- predict(s$fits$XGBoost,new_data=z$holdout)$.pred
# Fixed original blend on the dollar scale, not weights selected against holdout.
p_blend <- log(cfg$linear_weight*exp(p_lm)+(1-cfg$linear_weight)*exp(p_xgb))
pred <- tibble(Id=z$holdout$Id,SalePrice=z$holdout$SalePrice,
              Linear=p_lm,XGBoost=p_xgb,Blend=p_blend)
if (any(!is.finite(as.matrix(pred)))) stop("Non-finite predictions.")
score <- function(y,p) c(rmse_log=sqrt(mean((log(y)-p)^2)),
  rmse_usd=sqrt(mean((y-exp(p))^2)),mae_usd=mean(abs(y-exp(p))),
  r2_predictive=1-sum((y-exp(p))^2)/sum((y-mean(y))^2))
models <- c("Linear","XGBoost","Blend")
metric_table <- function(ix) map_dfr(models,function(m) {
 a <- score(pred$SalePrice[ix],pred[[m]][ix]);tibble(model=m,metric=names(a),value=unname(a))})
point <- metric_table(seq_len(nrow(pred)))
write_table(pred,"holdout_predictions_log.csv"); write_table(point,"holdout_metrics.csv")
# Approximate iid-house bootstrap, conditional on fitted models. No CV t-test.
set.seed(cfg$seed_boot)
boot <- map_dfr(seq_len(cfg$B),function(b) metric_table(sample.int(nrow(pred),replace=TRUE)) %>% mutate(replica=b))
ci <- boot %>% group_by(model,metric) %>% summarise(valid=sum(is.finite(value)),
 lower=quantile(value,.025,na.rm=TRUE),upper=quantile(value,.975,na.rm=TRUE),.groups="drop") %>%
 left_join(point,by=c("model","metric"))
write_table(ci,"holdout_metric_ci.csv")
delta <- boot %>% pivot_wider(names_from=model,values_from=value) %>%
 pivot_longer(c(XGBoost,Blend),names_to="candidate",values_to="candidate_value") %>%
 mutate(improvement=if_else(metric=="r2_predictive",candidate_value-Linear,Linear-candidate_value))
point_delta <- point %>% pivot_wider(names_from=model,values_from=value) %>%
 pivot_longer(c(XGBoost,Blend),names_to="candidate",values_to="candidate_value") %>%
 mutate(improvement=if_else(metric=="r2_predictive",candidate_value-Linear,Linear-candidate_value)) %>%
 select(metric,candidate,improvement)
write_table(delta %>% group_by(candidate,metric) %>% summarise(valid=sum(is.finite(improvement)),
 lower=quantile(improvement,.025,na.rm=TRUE),upper=quantile(improvement,.975,na.rm=TRUE),.groups="drop") %>%
 left_join(point_delta,by=c("metric","candidate")),"paired_improvement_ci.csv")
long <- pred %>% pivot_longer(all_of(models),names_to="model",values_to="pred_log") %>%
 mutate(pred_usd=exp(pred_log),residual_usd=SalePrice-pred_usd)
save_plot(ggplot(long,aes(SalePrice,pred_usd))+geom_point(alpha=.5)+
 geom_abline(slope=1,intercept=0,color="red")+facet_wrap(~model)+coord_equal()+theme_bw()+
 labs(x="Observed price (USD)",y="Predicted price (USD)"),"observed_vs_predicted.png")
save_plot(ggplot(long,aes(pred_usd,residual_usd))+geom_point(alpha=.5)+
 geom_hline(yintercept=0,color="red")+facet_wrap(~model)+theme_bw()+
 labs(x="Predicted price (USD)",y="Observed - predicted (USD)"),"residuals.png")
print(ci)
