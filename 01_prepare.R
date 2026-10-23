source("00_config.R")
if (!file.exists(train_path) || !file.exists(test_path)) stop("See data/raw/README.md for input files.")
train <- readr::read_csv(train_path,na=c("", "NA"),show_col_types=FALSE)
test <- readr::read_csv(test_path,na=c("", "NA"),show_col_types=FALSE)
stopifnot(nrow(train)==1460L,nrow(test)==1459L,ncol(train)==81L,ncol(test)==80L,
          !anyDuplicated(train$Id),!anyDuplicated(test$Id),
          !length(intersect(train$Id,test$Id)),all(is.finite(train$SalePrice)),all(train$SalePrice>0))
stopifnot(setequal(setdiff(names(train),"SalePrice"),names(test)))
# Explicit target scale avoids skipped recipe transformations and mixed-scale CV.
train <- train %>% mutate(log_price=log(SalePrice))
set.seed(cfg$seed_split)
split <- initial_split(train,prop=cfg$prop_train,strata=SalePrice)
training_data <- training(split); holdout <- testing(split)
set.seed(cfg$seed_folds)
folds <- vfold_cv(training_data,v=cfg$folds,strata=SalePrice)
numeric_features <- names(train)[vapply(train,is.numeric,logical(1))]
numeric_features <- setdiff(numeric_features,c("Id","SalePrice","log_price","MSSubClass"))
categorical_features <- c("MSSubClass","Neighborhood","ExterQual","BsmtQual","KitchenQual","GarageFinish")
predictors <- c(numeric_features,categorical_features)
# Factors are interpreted within recipes; no global imputation or outcome screening.
model_recipe <- recipe(log_price ~ .,data=training_data %>% select(log_price,all_of(predictors))) %>%
  step_mutate(MSSubClass=as.character(MSSubClass)) %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_mutate(HouseAge=YrSold-YearBuilt,
              TotalPorch=OpenPorchSF+EnclosedPorch+ScreenPorch+`3SsnPorch`,
              TotalBath=BsmtFullBath+FullBath+.5*BsmtHalfBath+.5*HalfBath,
              HasPool=as.numeric(PoolArea>0),HasFireplace=as.numeric(Fireplaces>0)) %>%
  step_log(LotArea) %>%
  step_unknown(all_nominal_predictors(),new_level="missing") %>%
  step_novel(all_nominal_predictors(),new_level="new_level") %>%
  step_dummy(all_nominal_predictors()) %>%
  step_zv(all_predictors()) %>% step_lincomb(all_numeric_predictors()) %>%
  step_normalize(all_numeric_predictors())
# A fixed feature specification informed by earlier work, not a fresh discovery study.
scripts <- c("00_config.R","01_prepare.R","02_fit.R","03_evaluate.R","04_submission.R")
signature <- digest::digest(list(cfg,unname(tools::md5sum(c(train_path,test_path,scripts))),
  vapply(packages,function(x) as.character(packageVersion(x)),character(1))))
path <- file.path(run_dir,"prepared.rds")
if (file.exists(path) && !identical(readRDS(path)$signature,signature)) stop("Inputs/configuration changed; use a new run_dir.")
saveRDS(list(train=train,test=test,training=training_data,holdout=holdout,folds=folds,
 recipe=model_recipe,predictors=predictors,signature=signature,cfg=cfg),path)
write_table(tibble(partition=c("training","internal_holdout","Kaggle_unlabelled"),
                  n=c(nrow(training_data),nrow(holdout),nrow(test))),"partition.csv")
writeLines(capture.output(sessionInfo()),file.path(run_dir,"sessionInfo.txt"))
