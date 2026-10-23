###### direccion 
setwd("C:/Users/DELL/OneDrive/Escritorio/kaggle/House Price")
########## librerias
library(tidyverse)
library(tidymodels)
library(nortest)
############################# carga de datos 
Prueba <- read_delim("test.csv", delim = ";", escape_double = FALSE, trim_ws = TRUE)
Entrenamiento <- read_delim("train.csv", delim = ";", escape_double = FALSE, trim_ws =TRUE)
#decision imputar con la mediana 
mediana_GarageYrBlt<-median(Entrenamiento$GarageYrBlt,na.rm = TRUE)
mediana_LotFrontage<-median(Entrenamiento$LotFrontage,na.rm = TRUE)
mediana_MasVnrArea<-median(Entrenamiento$MasVnrArea,na.rm = TRUE)
#eliminando la variabl objetico de Entrenamiento 
SalePrice<-Entrenamiento$SalePrice
Entrenamiento<-Entrenamiento%>%select(-SalePrice)
#uniendo ambos data para la imputacion general 
Entrenamiento$origen<-"Train"
Prueba$origen<-"Test"
full_data<-bind_rows(Entrenamiento,Prueba)
#imputacion de las variables numericas 
full_data<-full_data%>%mutate(
  LotFrontage=replace_na(LotFrontage,mediana_LotFrontage),
  MasVnrArea=replace_na(MasVnrArea,mediana_MasVnrArea),
  GarageYrBlt=replace_na(GarageYrBlt,mediana_GarageYrBlt)
)
#imputando las variables tipo caracter 
full_data<-full_data%>%mutate(
  across(where(is.character),~replace_na(.,"None")))
#verificando si queda algun NA
colSums(is.na(full_data))
vars_num_con_na<-full_data%>%select(where(is.numeric))%>%summarise(across(everything(),
                                                                          ~sum(is.na(.))))%>%gather(variable,conteo)%>%filter(conteo>0)%>%pull(variable)
for(col in vars_num_con_na){
  mediana<-median(Entrenamiento[[col]],na.rm = TRUE)
  full_data[[col]][is.na(full_data[[col]])]<-mediana
  print(paste("Imputada variable:",col,"con valor:",mediana))
}
Entrenamiento_limpio<-full_data%>%filter(origen=="Train")%>%select(-origen)
Prueba_limpio<-full_data%>%filter(origen=="Test")%>%select(-origen)
colSums(is.na(Prueba_limpio))
#analisis exploratoria del conjunto de datos de entrenamiento limpio 
Entrenamiento_limpio$SalePrice<-SalePrice
colSums(is.na(Prueba_limpio))
#separando data set 
Entrenamiento_limpio<-full_data%>%filter(origen=="Train")%>%select(-origen)
Prueba_limpio<-full_data%>%filter(origen=="Test")%>%select(-origen)
Entrenamiento_limpio<-Entrenamiento_limpio%>%mutate(SalePrice=SalePrice)
Train_filtrado<-Entrenamiento_limpio
Train_filtrado<-Train_filtrado%>%filter(GrLivArea<3500)
vars_categoricas_top<-c("Neighborhood","ExterQual","BsmtQual","KitchenQual","GarageFinish")
#split
data_split<-initial_split(Train_filtrado,prop = 0.8,strata = SalePrice)
Train_split<-training(data_split)
Test_split<-testing(data_split)
#receta
receta<-recipe(SalePrice~.,data = Train_split)%>%step_log(all_outcomes(),skip = TRUE)%>%
  step_log(LotArea)%>%
  step_rename(Flr1_sl=`1stFlrSF`,Flr2_SF=`2ndFlrSF`)%>%step_mutate(
    Age_House=YrSold-YearBuilt,Total_porch=OpenPorchSF+EnclosedPorch+ScreenPorch+`3SsnPorch`,
    Has_porch=ifelse(Total_porch>0,1,0),TotalBath=BsmtFullBath+FullBath+0.5*BsmtHalfBath+0.5*HalfBath,
    OverallCond_grupo=case_when(
      OverallCond<=4~ 1, #Baja#
      OverallCond<=7~ 2 , #"Media"
      TRUE~3  #"Alta"
    ),has_pool=ifelse(PoolArea>0,1,0),has_misc=ifelse(MiscVal>0,1,0),has_fireplaces=ifelse(
      Fireplaces>0,1,0),has_masvnrarea=ifelse(MasVnrArea>0,1,0))%>%
  step_select(all_numeric_predictors(),all_of(vars_categoricas_top),has_role("outcome"),skip = TRUE)%>%
  step_other(Neighborhood,threshold = 0.005)%>%
  step_string2factor(all_of(vars_categoricas_top))%>%step_novel(all_nominal_predictors(),
                                                                new_level = "new_category")%>%
  step_unknown(all_nominal_predictors(),new_level = "unknown")%>%step_dummy(all_of(vars_categoricas_top))%>%
  step_rm(any_of(c("YearBuilt","MiscVal","YearRemodAdd","YrSold","Flr1_sl","Flr2_SF","TotalBsmtSF",
                   "Id","OverallCond","GarageArea","Total_porch","OpenPorchSF",
                   "EnclosedPorch","ScreenPorch","3SsnPorch","MoSold","BsmtFullBath",
                   "FullBath","BsmtHalfBath","HalfBath","BsmtFinSF1",
                   "BsmtFinSF2","BsmtUnfSF","LowQualFinSF",
                   "TotRmsAbvGrd","KitchenAbvGr","BedroomAbvGr","PoolArea","Fireplaces","MasVnrArea")))%>%step_normalize(
                     all_integer_predictors())

#para la regresion lineal
#modelo
modelo_lr<-linear_reg()%>%set_engine("lm")
#workflow
house_workflow<-workflow()%>%add_recipe(receta)%>%add_model(modelo_lr)
#entrenar y evaluar 
fit_i<-house_workflow%>%fit(data = Train_split)
predicciones<-exp(predict(fit_i,new_data = Train_split))%>%
  bind_cols(Train_split%>%select(SalePrice))
print(predicciones%>%metrics(truth=SalePrice,estimate=.pred))
#evaluando en el test split
predic_test_split<-exp(predict(fit_i,new_data = Test_split))%>%bind_cols(Test_split%>%select(SalePrice))
print(predic_test_split%>%metrics(truth = SalePrice,estimate = .pred))
#distancia cook
model_metrics<-fit_i%>%extract_fit_engine()%>%augment()%>%mutate(index=row_number())
umbral<-4/nrow(model_metrics)
ggplot(model_metrics,aes(x=index,y=.cooksd))+geom_segment(
  aes(xend = index,yend = 0),color="steelblue")+geom_hline(yintercept = umbral,
        color="red",linetype="dashed")+labs(title = "Distnacia Cook via tidymodels",
                                            x="Indice de Observacion",
                                            y="Cook's D")+theme_minimal()
atipicos_influyentes<-model_metrics%>%filter(.cooksd>umbral)
atipicos_influyentes<-atipicos_influyentes%>%mutate(Precio_rea=exp(..y),
                                                    Precio_pred=exp(.fitted),
                                                    error=Precio_rea-Precio_pred)
#creando un data ser limpio sin eso atipicos infliyentes
indice_atipicos<-model_metrics%>%filter(.cooksd>umbral)%>%pull(index)
Train_split_clean<-Train_split%>%slice(-indice_atipicos)

receta_sin_atip<-recipe(SalePrice~.,data = Train_split_clean)%>%step_log(all_outcomes(),skip = TRUE)%>%
  step_log(LotArea)%>%
  step_rename(Flr1_sl=`1stFlrSF`,Flr2_SF=`2ndFlrSF`)%>%step_mutate(
    Age_House=YrSold-YearBuilt,Total_porch=OpenPorchSF+EnclosedPorch+ScreenPorch+`3SsnPorch`,
    Has_porch=ifelse(Total_porch>0,1,0),TotalBath=BsmtFullBath+FullBath+0.5*BsmtHalfBath+0.5*HalfBath,
    OverallCond_grupo=case_when(
      OverallCond<=4~ 1, #Baja#
      OverallCond<=7~ 2 , #"Media"
      TRUE~3  #"Alta"
    ),has_pool=ifelse(PoolArea>0,1,0),has_misc=ifelse(MiscVal>0,1,0),has_fireplaces=ifelse(
      Fireplaces>0,1,0),has_masvnrarea=ifelse(MasVnrArea>0,1,0))%>%
  step_select(all_numeric_predictors(),all_of(vars_categoricas_top),has_role("outcome"),skip = TRUE)%>%
  step_other(Neighborhood,threshold = 0.005)%>%
  step_string2factor(all_of(vars_categoricas_top))%>%step_novel(all_nominal_predictors(),
                                                                new_level = "new_category")%>%
  step_unknown(all_nominal_predictors(),new_level = "unknown")%>%step_dummy(all_of(vars_categoricas_top))%>%
  step_rm(any_of(c("YearBuilt","MiscVal","YearRemodAdd","YrSold","Flr1_sl","Flr2_SF","TotalBsmtSF",
                   "Id","OverallCond","GarageArea","Total_porch","OpenPorchSF",
                   "EnclosedPorch","ScreenPorch","3SsnPorch","MoSold","BsmtFullBath",
                   "FullBath","BsmtHalfBath","HalfBath","BsmtFinSF1",
                   "BsmtFinSF2","BsmtUnfSF","LowQualFinSF",
                   "TotRmsAbvGrd","KitchenAbvGr","BedroomAbvGr","PoolArea","Fireplaces","MasVnrArea")))%>%step_normalize(
                     all_integer_predictors())
modelo_lr<-linear_reg()%>%set_engine("lm")
#workflow
house_workflow_SA<-workflow()%>%add_recipe(receta_sin_atip)%>%add_model(modelo_lr)
#entrenar y evaluar 
fit_sin_atip<-house_workflow_SA%>%fit(data = Train_split_clean)
predicciones_SA<-exp(predict(fit_sin_atip,new_data = Train_split_clean))%>%
  bind_cols(Train_split_clean%>%select(SalePrice))
print(predicciones_SA%>%metrics(truth=SalePrice,estimate=.pred))
#probando en el test
predic_test_split_SA<-exp(predict(fit_sin_atip,new_data = Test_split))%>%bind_cols(Test_split%>%select(SalePrice))
print(predic_test_split_SA%>%metrics(truth = SalePrice,estimate = .pred))
#probando en con el set prueba 
sample_lineal<-exp(predict(fit_sin_atip,new_data = Prueba_limpio))
sample_lineal<-sample_lineal%>%transmute(Id=Prueba_limpio$Id,SalePrice=.pred)
sample_xgb<-exp(predict(xgb_fit,new_data = Prueba_limpio))
sample_xgb<-sample_xgb%>%transmute(Id=Prueba_limpio$Id,SalePrice=.pred)
write.csv(sample_lineal,"sample_submision_l.csv",row.names = FALSE)
write.csv(sample_xgb,"sample_submision_xgb.csv",row.names = FALSE)
sample_combinado<-as.data.frame(sample_lineal$Id)
sample_combinado<-sample_combinado%>%transmute(Id=`sample_lineal$Id`,
                      SalePrice=0.6*sample_lineal$SalePrice+0.4*sample_xgb$SalePrice)
write.csv(sample_combinado,"sample_submision_comb.csv",row.names = FALSE)
sample_combinado2<-as.data.frame(sample_lineal$Id)
sample_combinado2<-sample_combinado2%>%transmute(Id=`sample_lineal$Id`,
                                               SalePrice=0.6055*sample_lineal$SalePrice+0.3945*sample_xgb$SalePrice)
write.csv(sample_combinado2,"sample_submision_comb7.csv",row.names = FALSE)
#asigando pesos
p<-seq(0.5,0.8,by=0.01)
library(purrr)

map_df(p,function(w){
  p_blend<-w*predic_test_split$.pred+(1-w)*result_base$SalePrice_estimado
  rmse_val<-yardstick::rmse_vec(result_base$Real,p_blend)
  tibble(w_linear=w,rmse=rmse_val)
})%>%arrange(rmse)
#probando el xgb
library(xgboost)
xgb_spec<-boost_tree(trees = 842,min_n = 20, tree_depth = 5, learn_rate = 0.234,
                     loss_reduction = 0.0000000001)%>%set_engine("xgboost")%>%set_mode("regression")
xgb_workflow<-workflow()%>%add_recipe(receta)%>%add_model(xgb_spec)
xgb_fit<-xgb_workflow%>%fit(data = Train_filtrado)
resul_train<-predict(xgb_fit,Train_filtrado)
resul_train<-resul_train%>%transmute(Sale=exp(.pred),Sale_real=Train_filtrado$SalePrice)
print(resul_train%>%metrics(truth = Sale_real,estimate = Sale))
result_base<-predict(xgb_fit, Test_split)
result_base<-result_base%>%mutate(SalePrice_estimado=exp(.pred),Real=Test_split$SalePrice)
print(result_base%>%metrics(truth = Real,estimate = SalePrice_estimado))
#haciendo el tune para el xgb
#tuned del modelo 
xgb_spec_tuned<-boost_tree(
  trees = tune(),
  tree_depth=tune(),
  min_n = tune(),
  loss_reduction = tune(),
  learn_rate = tune())%>%set_engine("xgboost")%>%set_mode("regression")
xgb_wf<-workflow()%>%add_recipe(receta)%>%add_model(xgb_spec_tuned)
set.seed(26)
folds<-vfold_cv(Train_split,v=5)
xgb_res<-tune_grid(xgb_wf,resamples = folds,grid = 20,control = control_grid(save_pred = TRUE))

best_xgb<-select_best(xgb_res)
print(best_xgb)
#asigando pesos 
peso<-as.data.frame(predic_test_split_SA$SalePrice)
peso<-peso%>%transmute(SalePrice=`predic_test_split_SA$SalePrice`,Lineal=predic_test_split_SA$.pred,xgb=result_base$SalePrice_estimado)
cor(peso)
