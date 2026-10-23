# Revised OLS/FGLS comparison. Base R only; original experiments remain in source/.
read_house_csv <- function(path) {
  header <- readLines(path,n=1,warn=FALSE)
  read.table(path,header=TRUE,sep=if(grepl(';',header,fixed=TRUE)) ';' else ',',
             stringsAsFactors=FALSE,check.names=FALSE,na.strings=c('NA',''),comment.char='',quote='"')
}
raw_numeric <- c('MSSubClass','LotFrontage','LotArea','OverallQual','GrLivArea',
 'GarageYrBlt','GarageCars','WoodDeckSF','YrSold','YearBuilt','OpenPorchSF',
 'EnclosedPorch','ScreenPorch','3SsnPorch','BsmtFullBath','FullBath','BsmtHalfBath',
 'HalfBath','OverallCond','PoolArea','MiscVal','Fireplaces','MasVnrArea')
raw_categorical <- c('Neighborhood','ExterQual','BsmtQual','KitchenQual','GarageFinish')
engineer_house <- function(data,medians) {
  d<-data
  for(k in raw_numeric) {v<-as.numeric(d[[k]]);v[is.na(v)]<-medians[[k]];d[[k]]<-v}
  data.frame(MSSubClass=d$MSSubClass,LotFrontage=d$LotFrontage,log_LotArea=log(pmax(d$LotArea,1)),
   OverallQual=d$OverallQual,GrLivArea=d$GrLivArea,GarageYrBlt=d$GarageYrBlt,
   GarageCars=d$GarageCars,WoodDeckSF=d$WoodDeckSF,Age_House=d$YrSold-d$YearBuilt,
   Has_porch=as.numeric((d$OpenPorchSF+d$EnclosedPorch+d$ScreenPorch+d[['3SsnPorch']])>0),
   TotalBath=d$BsmtFullBath+d$FullBath+.5*d$BsmtHalfBath+.5*d$HalfBath,
   OverallCond_grupo=as.character(ifelse(d$OverallCond<=4,'Low',ifelse(d$OverallCond<=7,'Medium','High'))),
   has_pool=as.numeric(d$PoolArea>0),has_misc=as.numeric(d$MiscVal>0),
   has_fireplaces=as.numeric(d$Fireplaces>0),has_masvnrarea=as.numeric(d$MasVnrArea>0),
   d[raw_categorical],check.names=FALSE)
}
map_category <- function(v,rule) {
  v<-as.character(v);v[is.na(v)]<-rule$missing
  v[!v %in% rule$keep]<-rule$fallback
  factor(v,levels=rule$levels)
}
bake_house <- function(prep,data,full=FALSE) {
  d<-engineer_house(data,prep$medians)
  for(k in names(prep$categories)) d[[k]]<-map_category(d[[k]],prep$categories[[k]])
  d<-d[prep$variables]
  x<-model.matrix(~.,data=d,contrasts.arg=prep$contrasts)
  stopifnot(identical(colnames(x),prep$matrix_columns),all(is.finite(x)))
  if(full) return(x)
  out<-sweep(sweep(x,2,prep$centers,'-'),2,prep$scales,'/')
  out<-out[,prep$independent,drop=FALSE];colnames(out)<-prep$feature_names
  as.data.frame(out,check.names=FALSE)
}
fit_house_preprocessor <- function(data) {
  medians<-vapply(data[raw_numeric],function(v) median(as.numeric(v),na.rm=TRUE),numeric(1))
  if(any(!is.finite(medians))) stop('Numeric field entirely missing in this training partition.')
  d<-engineer_house(data,medians);categorical<-names(d)[vapply(d,is.character,logical(1))]
  categories<-list()
  for(k in categorical) {
    missing<-if(k %in% c('BsmtQual','GarageFinish')) 'None' else 'Unknown'
    v<-d[[k]];v[is.na(v)]<-missing;tab<-table(v)
    keep<-if(k=='Neighborhood') names(tab)[tab>=max(2,ceiling(.005*nrow(d)))] else names(tab)[tab>=2]
    if(!length(keep)) keep<-names(tab)[which.max(tab)]
    rare<-v[!v %in% keep];fallback<-if(length(rare)>=2) 'Other' else names(tab)[which.max(tab)]
    mapped<-v;mapped[!mapped %in% keep]<-fallback
    rule<-list(missing=missing,keep=keep,fallback=fallback,levels=sort(unique(mapped)))
    categories[[k]]<-rule;d[[k]]<-map_category(v,rule)
  }
  variables<-names(d)[vapply(d,function(v) length(unique(v))>1,logical(1))]
  d<-d[variables];contrasts<-lapply(d[vapply(d,is.factor,logical(1))],function(v) contrasts(v,contrasts=TRUE))
  x<-model.matrix(~.,d,contrasts.arg=contrasts)
  centers<-colMeans(x);scales<-apply(x,2,sd);centers[1]<-0;scales[1]<-1
  scales[!is.finite(scales)|scales==0]<-1
  z<-sweep(sweep(x,2,centers,'-'),2,scales,'/')
  qr_x<-qr(z,tol=1e-8);independent<-sort(qr_x$pivot[seq_len(qr_x$rank)])
  prep<-list(medians=medians,categories=categories,variables=variables,contrasts=contrasts,
    matrix_columns=colnames(x),centers=centers,scales=scales,independent=independent,
    feature_names=paste0('x',seq_along(independent)),original_names=colnames(x)[independent],
    removed_dependent=setdiff(colnames(x),colnames(x)[independent]))
  prep
}
fit_house_models <- function(training,area_limit=Inf) {
  kept<-training[is.finite(training$GrLivArea)&training$GrLivArea<area_limit,,drop=FALSE]
  if(nrow(kept)<200) stop('Training partition too small.')
  prep<-fit_house_preprocessor(kept);x<-bake_house(prep,kept)
  # x1 is the explicit intercept from model.matrix; use -1 to avoid adding another.
  base<-data.frame(y=log(kept$SalePrice),x,check.names=FALSE)
  ols<-lm(y~.-1,data=base)
  stopifnot(ols$rank==ncol(x))
  eps<-max(1e-10,median(residuals(ols)^2)*1e-4)
  variance_data<-data.frame(log_res2=log(pmax(residuals(ols)^2,eps)),mu=fitted(ols))
  variance_model<-lm(log_res2~mu,data=variance_data)
  inverse_variance<-exp(-fitted(variance_model));weight_scale<-mean(inverse_variance)
  w<-inverse_variance/weight_scale
  fgls<-lm(y~.-1,data=base,weights=w)
  stopifnot(fgls$rank==ncol(x),all(is.finite(w)),all(w>0))
  list(prep=prep,ols=ols,fgls=fgls,variance_model=variance_model,weight_scale=weight_scale,
       area_limit=area_limit,n_training=nrow(kept),training_ids=kept$Id)
}
predict_house_models <- function(object,newdata,interval=FALSE) {
  x<-bake_house(object$prep,newdata)
  ols<-predict(object$ols,newdata=x)
  weights_new<-exp(-predict(object$variance_model,newdata=data.frame(mu=as.numeric(ols))))/object$weight_scale
  if(interval) list(OLS=predict(object$ols,newdata=x,interval='prediction',level=.95),
    FGLS=predict(object$fgls,newdata=x,interval='prediction',level=.95,weights=as.numeric(weights_new)))
  else list(OLS=as.numeric(ols),FGLS=as.numeric(predict(object$fgls,newdata=x)))
}
score_house <- function(truth,pred_log) {
  pred<-exp(pred_log)
  c(rmse_log=sqrt(mean((log(truth)-pred_log)^2)),rmse_usd=sqrt(mean((truth-pred)^2)),
    mae_usd=mean(abs(truth-pred)),r2_predictive=1-sum((truth-pred)^2)/sum((truth-mean(truth))^2),
    squared_correlation=cor(truth,pred)^2)
}
strata_house <- function(y) cut(log(y),unique(quantile(log(y),seq(0,1,.25))),include.lowest=TRUE,labels=FALSE)
random_indices <- function(data,prop=.8,seed=123) {
  set.seed(seed);sample(seq_len(nrow(data)),floor(nrow(data)*prop))
}
fold_ids_house <- function(data,v=10,seed=42) {
  set.seed(seed);ids<-integer(nrow(data))
  for(i in split(seq_len(nrow(data)),strata_house(data$SalePrice))) ids[i]<-sample(rep(seq_len(v),length.out=length(i)))
  ids
}
conformal_q <- function(scores,alpha=.05) {
  k<-ceiling((length(scores)+1)*(1-alpha))
  if(k>length(scores)) Inf else sort(scores)[k]
}
interval_summary <- function(truth,lower,upper,method) {
  covered<-truth>=lower&truth<=upper;n<-length(truth)
  ci<-binom.test(sum(covered),n,conf.level=.95)$conf.int
  data.frame(method=method,n=n,coverage=mean(covered),coverage_ci_lower=ci[1],coverage_ci_upper=ci[2],
             mean_width_usd=mean(upper-lower),median_width_usd=median(upper-lower))
}
run_house_analysis <- function(output='reports/revised',v=10) {
  dir.create(file.path(output,'figures'),recursive=TRUE,showWarnings=FALSE)
  raw<-read_house_csv('data/raw/train.csv');kaggle<-read_house_csv('data/raw/test.csv')
  stopifnot(!anyNA(raw$SalePrice),all(raw$SalePrice>0),!anyDuplicated(raw$Id))
  split_i<-random_indices(raw);train<-raw[split_i,];test<-raw[-split_i,]
  folds<-fold_ids_house(train,v=v);cv<-list();at<-1L
  # Two prespecified sensitivity policies, assessed on exactly the same validation folds.
  policies<-c(all_properties=Inf,training_area_lt4000=4000)
  for(policy in names(policies)) for(fold in seq_len(v)) {
    analysis<-train[folds!=fold,];assessment<-train[folds==fold,]
    fitted<-fit_house_models(analysis,policies[[policy]])
    p<-predict_house_models(fitted,assessment)
    for(model in names(p)) {cv[[at]]<-data.frame(policy=policy,model=model,fold=fold,
      n_analysis=nrow(analysis),n_fitted=fitted$n_training,n_assessment=nrow(assessment),
      as.list(score_house(assessment$SalePrice,p[[model]])));at<-at+1L}
  }
  cv<-do.call(rbind,cv);summary<-aggregate(cv[c('rmse_log','rmse_usd','mae_usd','r2_predictive','squared_correlation')],cv[c('policy','model')],mean)
  chosen<-summary[which.min(summary$rmse_log),];chosen_model<-as.character(chosen$model);chosen_policy<-as.character(chosen$policy)
  final<-fit_house_models(train,policies[[chosen_policy]]);p<-predict_house_models(final,test)
  metrics<-do.call(rbind,lapply(names(p),function(m) data.frame(policy=chosen_policy,model=m,n=nrow(test),as.list(score_house(test$SalePrice,p[[m]])))))
  pred<-data.frame(Id=test$Id,SalePrice=test$SalePrice,log_observed=log(test$SalePrice),OLS_log=p$OLS,FGLS_log=p$FGLS)
  parametric<-predict_house_models(final,test,interval=TRUE)
  intervals<-list();summaries<-list()
  for(m in names(parametric)) {
    z<-parametric[[m]];lower<-exp(z[,'lwr']);upper<-exp(z[,'upr'])
    label<-paste0(m,' parametric')
    intervals[[m]]<-data.frame(Id=test$Id,SalePrice=test$SalePrice,method=label,predicted=exp(z[,'fit']),lower=lower,upper=upper)
    summaries[[m]]<-interval_summary(test$SalePrice,lower,upper,label)
  }
  # A separate proper-training fit, never refitted after reading calibration residuals.
  proper_i<-random_indices(train,prop=.75,seed=2026)
  proper<-train[proper_i,];calibration<-train[-proper_i,]
  cp<-fit_house_models(proper,Inf)
  cal_pred<-predict_house_models(cp,calibration)$OLS
  q<-conformal_q(abs(log(calibration$SalePrice)-cal_pred))
  cp_pred<-predict_house_models(cp,test)$OLS
  lo<-exp(cp_pred-q);up<-exp(cp_pred+q)
  intervals$conformal<-data.frame(Id=test$Id,SalePrice=test$SalePrice,method='OLS split conformal',predicted=exp(cp_pred),lower=lo,upper=up)
  summaries$conformal<-interval_summary(test$SalePrice,lo,up,'OLS split conformal')
  coverage<-do.call(rbind,summaries);interval_rows<-do.call(rbind,intervals)
  # Conformal family is fixed OLS/all-properties, independent of CV selection.
  write.csv(cv,file.path(output,'cv_fold_metrics.csv'),row.names=FALSE)
  write.csv(summary,file.path(output,'cv_summary.csv'),row.names=FALSE)
  write.csv(metrics,file.path(output,'holdout_metrics.csv'),row.names=FALSE)
  write.csv(pred,file.path(output,'holdout_predictions.csv'),row.names=FALSE)
  write.csv(coverage,file.path(output,'interval_summary.csv'),row.names=FALSE)
  write.csv(interval_rows,file.path(output,'holdout_prediction_intervals.csv'),row.names=FALSE)
  write.csv(data.frame(Id=c(train$Id,test$Id),partition=c(rep('training',nrow(train)),rep('holdout',nrow(test)))),file.path(output,'split_ids.csv'),row.names=FALSE)
  write.csv(data.frame(Id=train$Id,fold=folds),file.path(output,'fold_assignments.csv'),row.names=FALSE)
  write.csv(data.frame(feature=final$prep$original_names),file.path(output,'model_features.csv'),row.names=FALSE)
  # Diagnostics of the assumed model error are on its fitted log scale.
  diagnostics<-data.frame(fitted=fitted(final$ols),residual=residuals(final$ols),cook=cooks.distance(final$ols))
  aux<-lm(I(residual^2)~fitted,data=diagnostics);stat<-nrow(diagnostics)*summary(aux)$r.squared
  diagnostic_summary<-data.frame(model='OLS',scale='log price',variance_statistic=stat,
    variance_df=1,variance_p_value=pchisq(stat,df=1,lower.tail=FALSE),max_cooks_distance=max(diagnostics$cook,na.rm=TRUE),undefined_cooks_count=sum(!is.finite(diagnostics$cook)),max_leverage=max(hatvalues(final$ols)))
  write.csv(diagnostic_summary,file.path(output,'diagnostics.csv'),row.names=FALSE)
  png(file.path(output,'figures','log_residual_diagnostics.png'),1100,850,res=130)
  par(mfrow=c(2,2),mar=c(4,4,3,1));plot(diagnostics$fitted,diagnostics$residual,pch=16,col='#1b496560',xlab='Fitted log price',ylab='Log residual',main='OLS training residuals');abline(h=0,col='red',lty=2)
  qqnorm(diagnostics$residual,pch=16,col='#1b496560',main='OLS log residual Q-Q');qqline(diagnostics$residual,col='red')
  plot(diagnostics$cook,type='h',xlab='Training row',ylab="Cook's distance",main='Influence — no automatic deletion')
  plot(log(test$SalePrice),p[[chosen_model]],pch=16,col='#1b496580',xlab='Observed log price',ylab='Predicted log price',main=paste(chosen_model,'holdout'));abline(0,1,col='red',lty=2);dev.off()
  png(file.path(output,'figures','interval_coverage.png'),1050,600,res=130);par(mar=c(6,5,3,1));xx<-seq_len(nrow(coverage));plot(xx,coverage$coverage,xlim=c(.6,3.4),ylim=range(c(.85,1,coverage$coverage_ci_lower)),xaxt='n',pch=19,xlab='',ylab='Observed holdout coverage',main='95% prediction intervals — coverage with binomial uncertainty');axis(1,at=xx,labels=c('OLS\nparametric','FGLS\nparametric','OLS split\nconformal'));arrows(xx,coverage$coverage_ci_lower,xx,coverage$coverage_ci_upper,angle=90,code=3,length=.08);abline(h=.95,lty=2,col='red');dev.off()
  # Submission is produced only after assessment; it carries no inferred Kaggle score.
  all_fit<-fit_house_models(raw,policies[[chosen_policy]])
  submission<-data.frame(Id=kaggle$Id,SalePrice=exp(predict_house_models(all_fit,kaggle)[[chosen_model]]))
  stopifnot(nrow(submission)==nrow(kaggle),identical(submission$Id,kaggle$Id),all(is.finite(submission$SalePrice)),all(submission$SalePrice>0))
  write.csv(submission,file.path(output,'submission_revised.csv'),row.names=FALSE)
  config<-list(seed_split=123,seed_folds=42,seed_calibration=2026,v=v,n_training=nrow(train),n_holdout=nrow(test),n_proper=nrow(proper),n_calibration=nrow(calibration),chosen_model=chosen_model,chosen_policy=chosen_policy,q95_log=q,rank=final$ols$rank,coefficient_count=length(coef(final$ols)))
  dput(config,file=file.path(output,'run_config.R'))
  writeLines(capture.output(sessionInfo()),file.path(output,'sessionInfo.txt'))
  list(cv_summary=summary,holdout_metrics=metrics,interval_summary=coverage,config=config)
}
