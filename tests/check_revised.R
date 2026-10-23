source('R/revised_analysis.R')
d<-read_house_csv('data/raw/train.csv');i<-random_indices(d);tr<-d[i,];te<-d[-i,]
stopifnot(!length(intersect(tr$Id,te$Id)),nrow(tr)+nrow(te)==nrow(d))
f<-fit_house_models(tr);x<-bake_house(f$prep,te)
stopifnot(identical(names(x),names(bake_house(f$prep,tr))),!anyNA(x),f$ols$rank==length(coef(f$ols)),f$fgls$rank==length(coef(f$fgls)))
# Incoming extreme/missing values cannot change learned imputation or encoding.
med<-f$prep$medians;novel<-te[1,,drop=FALSE];novel$Neighborhood<-'UNSEEN_NEIGHBORHOOD';novel$LotFrontage<-NA_real_
stopifnot(all(is.finite(as.matrix(bake_house(f$prep,novel)))),identical(med,f$prep$medians))
p<-predict_house_models(f,te,interval=TRUE)
stopifnot(all(p$OLS[,'lwr']<=p$OLS[,'fit']),all(p$FGLS[,'fit']<=p$FGLS[,'upr']))
# The finite-sample quantile must be an actual order statistic, not type-7 interpolation.
stopifnot(conformal_q(1:20,.05)==20,conformal_q(1:5,.05)==Inf)
cat('Partition, preprocessing, full-rank fits, novel input and interval checks passed.\n')
