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
Train_split<-Train_split%>%mutate(R_std=df_analisis$Res_std)%>%filter(abs(R_std)<=4)%>%select(-R_std)
#entrenar y evaluar
receta_xgb<-recipe(SalePrice~.,data = Train_split)%>%step_log(all_outcomes(),skip = TRUE)%>%
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
                   "TotRmsAbvGrd","KitchenAbvGr","BedroomAbvGr","PoolArea","Fireplaces","MasVnrArea")))
library(xgboost)
xgb_spec<-boost_tree(trees = 1684,min_n = 14, tree_depth = 15, learn_rate = 0.0280,
                     loss_reduction = 0.000000106)%>%set_engine("xgboost")%>%set_mode("regression")
xgb_workflow<-workflow()%>%add_recipe(receta_xgb)%>%add_model(xgb_spec)
xgb_fit<-xgb_workflow%>%fit(data = Train_filtrado)
resul_train<-predict(xgb_fit,Train_filtrado)
resul_train<-resul_train%>%transmute(Sale=exp(.pred))
resul_train<-resul_train%>%mutate(SalePrice=Train_filtrado$SalePrice,Res=SalePrice-Sale,R_std=(Res-mean(Res))/sd(Res))
result_base<-predict(xgb_fit, Train_filtrado)
result_base<-result_base%>%mutate(SalePrice_estimado=exp(.pred))
result_base<-result_base%>%mutate(SalePrice=Train_filtrado$SalePrice)
#result_base_mejor<-result_base_mejor%>%mutate(SalePrice_xgb_mejor=exp(.pred))
print(result_base%>%metrics(truth = SalePrice,estimate = SalePrice_estimado))
#importancia de las variables 
library(vip)
xgb_fit%>%extract_fit_parsnip()%>%vip(num_features=35)
result_base<-result_base%>%mutate(xgb_1=sample_submision_xgb$SalePrice_xgb)
sample_submision_xgb2<-exp(predict(xgb_fit,new_data=Prueba_limpio))
sample_submision_xgb3<-exp(predict(xgb_fit,new_data=Prueba_limpio))
sample_submision_xgb3<-sample_submision_xgb3%>%transmute(Id=Prueba_limpio$Id,SalePrice=.pred)
sample_submision_xgb2<-sample_submision_xgb2%>%transmute(Id=Prueba_limpio$Id,SalePrice=.pred)
write.csv(sample_submision_xgb3,"sample_submision_xgb4.csv", row.names = FALSE)
sample_submision_xgb<-exp(predict(xgb_fit,new_data=Prueba_limpio))
sample_submision_xgb<-sample_submision_xgb%>%transmute(Id=Prueba_limpio$Id,SalePrice=.pred)
write.csv(sample_submision_xgb,"sample_submision_xgb2.csv", row.names = FALSE)

library(writexl)
write_xlsx(sample_submision_xgb,"sample_submision_xgb2.xlsx")
#analisis de los residuales 
result_base<-result_base%>%mutate(residuales=SalePrice-SalePrice_estimado)
ggplot(data = result_base,aes(SalePrice_estimado,residuales))+geom_point(
  alpha=0.5,color="red")+geom_smooth(method = "loess",color="darkorange",se=FALSE)+
  labs(title = "Residuales vs Valores Ajustados",x="Prediccion",
       y="Residuales")+theme_minimal()
library(car)
crPlot(xgb_fit)
result_base<-result_base%>%mutate(residuales_std=(residuales-mean(residuales))/sd(residuales))
result_base%>%filter(abs(residuales_std)>4.95)
variables_numericas<-c("MSSubClass","MasVnrArea","GarageCars","OverallCond","LotFrontage",
                       "GrLivArea","WoodDeckSF","PoolArea","Fireplaces","LotArea","OverallQual",
                       "GarageYrBlt","GarageYrBlt","MiscVal")
vars_categoricas_top<-c("Neighborhood","ExterQual","BsmtQual","KitchenQual","GarageFinish")
df_analisis<-Train_split%>%select(all_of(variables_numericas),all_of(vars_categoricas_top),SalePrice)
df_analisis<-df_analisis%>%mutate(Res_std=resul_train$R_std)
view(df_analisis%>%filter(abs(Res_std)>4))
#filtrando atipocos 
Train_filtrado<-Train_filtrado%>%mutate(R_std=df_analisis$Res_std)%>%filter(abs(R_std)<4.5)%>%
  select(-R_std)
#tuned del modelo 
xgb_spec_tuned<-boost_tree(
  trees = tune(),
  tree_depth=tune(),
  min_n = tune(),
  loss_reduction = tune(),
  learn_rate = tune())%>%set_engine("xgboost")%>%set_mode("regression")
xgb_wf<-workflow()%>%add_recipe(receta_xgb)%>%add_model(xgb_spec_tuned)
set.seed(26)
folds<-vfold_cv(Train_split,v=5)
xgb_res<-tune_grid(xgb_wf,resamples = folds,grid = 20,control = control_grid(save_pred = TRUE))

best_xgb<-select_best(xgb_res)
print(best_xgb)
#importancia de las variables 
library(vip)
extract_workflow(xgb_fit)%>%extract_fit_parsnip()%>%vip()
#asigando pesos a los modelo 
peso<-