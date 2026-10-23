###### direccion 
setwd("C:/Users/DELL/OneDrive/Escritorio/kaggle/House Price")
########## librerias
library(tidyverse)
library(tidymodels)
library(nortest)
############################# carga de datos 
Prueba <- read_delim("test.csv", delim = ";", escape_double = FALSE, trim_ws = TRUE)
Entrenamiento <- read_delim("train.csv", delim = ";", escape_double = FALSE, trim_ws =TRUE)
################################################### EDA sobre Entrenamiento 
colSums(is.na(Entrenamiento))
#Analizando las variables tipo caracter 

Entrenamiento%>%select(where(is.character))%>%select(where(~any(is.na(.))))%>%
  gather(variable, valor)%>%count(variable, valor)%>%filter(is.na(valor))
#Analizando las tipo numerica 
Entrenamiento%>%select(where(is.numeric))%>%select(where(~any(is.na(.))))%>%
  gather(variable, valor)%>%count(variable, valor)%>%filter(is.na(valor))
vars_nan_numericas<-c("GarageYrBlt","LotFrontage","MasVnrArea")                       
for( k in vars_nan_numericas){
  par(mfrow=c(1,2))
  hist(Entrenamiento[[k]],main=paste("histograma de",k),col="blue",xlab=k)
  boxplot(Entrenamiento[[k]],main=paste("boxplot de",k),col="tomato",horizontal=TRUE)
  
  par(mfrow=c(1,1))
  
}
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

#seperando los data set 
full_data<-full_data%>%mutate(OverallCond_grupo=case_when(
  OverallCond<=4~ 1, #Baja#
  OverallCond<=7~ 2 , #"Media"
  TRUE~3  #"Alta"
))
Entrenamiento_limpio<-full_data%>%filter(origen=="Train")%>%select(-origen)
Prueba_limpio<-full_data%>%filter(origen=="Test")%>%select(-origen)
colSums(is.na(Prueba_limpio))
#analisis exploratoria del conjunto de datos de entrenamiento limpio 
Entrenamiento_limpio$SalePrice<-SalePrice
Entrenamiento_limpio%>%select(OverallQual,OverallCond,SalePrice)%>%cor()   

cor(Entrenamiento_limpio$OverallCond_grupo,Entrenamiento_limpio$SalePrice,method = "kendall")
cor(Entrenamiento_limpio$OverallCond_grupo,Entrenamiento_limpio$SalePrice,method = "spearman")
cor(Entrenamiento_limpio$OverallCond_grupo,Entrenamiento_limpio$SalePrice)
#correlacion
correlacion<-Entrenamiento_limpio%>%select(where(is.numeric))%>%select(-SalePrice)%>%cor()
lista_cor<-as.data.frame(as.table(correlacion))
multicolinealidad<-lista_cor%>%filter(abs(Freq)>0.5 & Var1 !=Var2)%>%mutate(orden=
                    pmin(as.character(Var1),as.character(Var2)))%>%distinct(orden,.keep_all = TRUE)%>%
  select(-orden)%>%arrange(desc(abs(Freq)))
print(multicolinealidad)  
#Analizando las variables categoricas 
vars_categoricas<-Entrenamiento_limpio%>%select(where(is.character))%>%colnames()
print(vars_categoricas)
vars_presentes<-vars_categoricas[vars_categoricas %in% colnames(Entrenamiento_limpio)]

categoricas<-Entrenamiento_limpio[,vars_presentes]
for(var in colnames(categoricas)){
  categoricas[[var]]<-as.factor(categoricas[[var]])
}
categoricas$SalePrice<-Entrenamiento_limpio$SalePrice
resultado_list<-list()
for(i in 1:ncol(categoricas)){
  nombre_var<-colnames(categoricas)[i]
  res_anova<-summary(aov(categoricas$SalePrice~categoricas[[i]]))
  p_val<-res_anova[[1]][["Pr(>F)"]][1]
  resultado_list[[i]]<-data.frame(Variable=nombre_var,P_valor=p_val)
}
tabla_anova<-do.call(rbind,resultado_list)
tabla_anova<-tabla_anova[order(tabla_anova$P_valor),]
print(tabla_anova)
#prueba de chi cuadrada
analizar_chi_cuadrado<-function(data){
  vars<-colnames(data)
  n<-length(data)
  resultado<-data_frame(var1=character(),var2=character(),P_valor=numeric())
  #combinaciones
  for(i in 1:(n-1)){
    for(j in (i+1):n){
      tabla<-table(data[[vars[i]]],data[[vars[j]]])
      prueba<-chisq.test(tabla,simulate.p.value = TRUE)
      resultado<-rbind(resultado,
                       data.frame(
                         var1=vars[[i]],
                         var2=vars[j],
                         P_valor=prueba$p.value
                       ))
    }
  }
  return(resultado[order(resultado$P_valor),])
}
chi<-analizar_chi_cuadrado(categoricas)
tail(chi,10)
#filtrando variables que con un p valor bajo en el anova y un p valor alto en chi cuadrado 
asociaciones_fuerte<-chi[chi$P_valor>0.001,]
vars_finales<-tabla_anova$Variable[tabla_anova$P_valor<0.05]
a_eliminar<-c()
for(i in 1:nrow(asociaciones_fuerte)){
  v1<-as.character(asociaciones_fuerte$Var1[i])
  v2<-as.character(asociaciones_fuerte$Var2[i])
  if(length(v1)>0 && length(v2)>0 && v1!="" && v2!=""){
  if(v1 %in% vars_finales & v2 %in% vars_finales){
    p1<-tabla_anova$P_valor[which(tabla_anova$Variable==v1)]
    p2<-tabla_anova$P_valor[which(tabla_anova$Variable==v2)]
    if(p1>p2){
      a_eliminar<-c(a_eliminar,v1)
    } else{
      a_eliminar<-c(a_eliminar,v2)
    }
  }
  }
  }
vars_finales<-setdiff(vars_finales,unique(a_eliminar))
print(vars_finales)
#calculando el eta cuadrado 
modelo_base<-lm(data=categoricas,SalePrice~1)
analisis_directo<-add1(modelo_base,scope = categoricas,test = "F")
ranking<-analisis_directo[order(-analisis_directo$`Sum of Sq`),]
head(ranking,10)
#se tomaran las primeras 10 variables 
vars_categoricas_top<-c("Neighborhood","ExterQual","BsmtQual","KitchenQual","GarageFinish")
print(vars_categoricas_top)
#receta
Train_filtrado<-Entrenamiento_limpio
Train_filtrado<-Train_filtrado%>%filter(GrLivArea<3500)
receta<-recipe(SalePrice~.,data = Train_filtrado)%>%step_log(all_outcomes(),skip = TRUE)%>%
  step_rename(Flr1_sl=`1stFlrSF`,Flr2_SF=`2ndFlrSF`)%>%step_mutate(
    Age_House=YrSold-YearBuilt,Total_porch=OpenPorchSF+EnclosedPorch+ScreenPorch+`3SsnPorch`,
    Has_porch=ifelse(Total_porch>0,1,0),TotalBath=BsmtFullBath+FullBath+0.5*BsmtHalfBath+0.5*HalfBath)%>%
  step_select(all_numeric_predictors(),all_of(vars_categoricas_top),has_role("outcome"),skip = TRUE)%>%
  step_string2factor(all_of(vars_categoricas_top))%>%
  step_dummy(all_of(vars_categoricas_top))%>%
  step_rm(any_of(c("YearBuilt","YearRemodAdd","YrSold","Flr1_sl","Flr2_SF","TotalBsmtSF",
                   "Id","OverallCond","GarageArea","Total_porch","OpenPorchSF",
                   "EnclosedPorch","ScreenPorch","3SsnPorch","MoSold","BsmtFullBath",
                   "FullBath","BsmtHalfBath","HalfBath","BsmtFinSF1",
                   "BsmtFinSF2","BsmtUnfSF","LowQualFinSF",
                   "TotRmsAbvGrd","KitchenAbvGr","BedroomAbvGr")))%>%step_corr(
    all_numeric_predictors(),threshold = 0.8)%>%step_normalize(all_numeric_predictors())

receta_preparada<-prep(receta)
#modelo
modelo_lr<-linear_reg()%>%set_engine("lm")
#workflow
house_workflow<-workflow()%>%add_recipe(receta)%>%add_model(modelo_lr)
#entrenar y evaluar 
fit_i<-house_workflow%>%fit(data = Train_filtrado)
print(tidy(fit_i)%>%arrange(desc(abs(estimate))),n=33)
#metricas de desempeno
print(glance(fit_i))
print(fit_i%>%extract_recipe()%>%summary()%>%filter(role=="predictor"),n=32)
#error cuadratico medio 
ic_train<-predict(fit_i,new_data = Train_filtrado,type = "pred_int")

predicciones<-exp(predict(fit_i,new_data = Train_filtrado))%>%
  bind_cols(Train_filtrado%>%select(SalePrice))
predicciones<-predicciones%>%mutate(Upper=exp(ic_train$.pred_upper),Lower=exp(
  ic_train$.pred_lower))
predicciones<-predicciones%>%mutate(inside=ifelse((SalePrice<=Upper & SalePrice>=Lower),"Yes","NO"))
table(predicciones$inside)
print(predicciones%>%metrics(truth=SalePrice,estimate=.pred))
write_xlsx(predicciones,"Intervalo_prediccion.xlsx")
#grafico de dispersion
ggplot(predicciones,aes(SalePrice,.pred))+
  geom_ribbon(aes(ymin = Lower,ymax = Upper),fill="orange",alpha=0.2)+
  geom_point(aes(color=inside),alpha=0.6)+scale_color_manual(values=c("Yes"="darkgreen",
                                                                      "NO"="red"))+
  geom_abline(slope = 1,intercept = 0,linetype="dashed")+
  labs(title = "Intervalo de prediccion(95%)",
       x="Real",y="Predicho")+theme_classic()
#importancia de la variables 
library(vip)
fit_i%>%extract_fit_parsnip()%>%vi()%>%mutate(
  Variable=fct_reorder(Variable,Importance))%>%ggplot(
    aes(Importance,Variable))+geom_col(fill="steelblue")+
  labs(title = "Variables Clave: Que define el Precio en House Price?",
       subtitle = "Basado en el Workflow entrenado",x="Importancia",
       y="NULL")+theme_classic()

##############
errores<-predicciones%>%select(Prediccion=.pred,SalePrice)
errores<-errores%>%mutate(GrLivArea=Entrenamiento_limpio$GrLivArea,error=abs(Prediccion-SalePrice))

#Estimaciones<-exp(predict(fit_i,new_data = Prueba_limpio))
#analisis de los residuales 
data_analisis<-augment(fit_i,new_data = Train_filtrado)
data_analisis<-data_analisis%>%select(Predic=.pred,SalePrice)
data_analisis<-data_analisis%>%mutate(Predic=exp(Predic))
data_analisis<-data_analisis%>%mutate(Residuo=SalePrice - Predic)
data_analisis<-data_analisis%>%mutate(Residuo_std=(Residuo-mean(Residuo))/sd(Residuo))
ggplot(data_analisis,aes(x=Predic,y=Residuo))+geom_point(alpha=0.5)+
  geom_hline(yintercept = 0,linetype="dashed",color="red")+
  labs(title = "Analisis de Residuos",x="Prediccion",y="Error")

ggplot(errores,aes(GrLivArea,SalePrice))+
  geom_point(alpha=0.4)+geom_smooth(method = "lm",color="red")+
  geom_vline(xintercept = 3000,linetype="dashed")
#conclusion filtrar para grLivearea<3500
#validacion cruzada
set.seed(123)
final_cv<-fit_resamples(house_workflow,
                        resamples = vfold_cv(Train_filtrado,v=10),
                        metrics = metric_set(rmse,rsq,mae),
                        control = control_resamples(save_pred = TRUE))
collect_metrics(final_cv)
preds<-final_cv%>%unnest(.predictions)
preds<-preds%>%select(SalePrice,Predit=.pred)
preds$P_real<-exp(preds$Predit)
print(preds%>%metrics(truth=SalePrice,estimate=P_real))
#ejecutar sobre el test 
predicciones_test<-predict(fit_i,new_data = Prueba_limpio)
sample_submission<-as.data.frame(Prueba_limpio$Id)
sample_submission$SalePrice<-exp(predicciones_test$.pred)
sample_submission$SalePrice<-exp(predicciones_test$.pred)
sample_submission<-sample_submission%>%transmute(Id=`Prueba_limpio$Id`,SalePrice)
colSums(is.na(sample_submission))
sample_submission<-sample_submission%>%mutate(
  SalePrice=replace_na(SalePrice,158044.8))
library(writexl)
write_xlsx(sample_submission,"sample_submission_2.xlsx")
#valores reales vs predicho
ggplot(preds,aes(log(SalePrice),log(P_real)))+geom_point(alpha=0.5,color="dodgerblue")+
  geom_abline(slope = 1,intercept = 0,color="red",linetype="dashed",size=1)+
  labs(title = "comparacion:Real vs Predicho",x="Valor Real",y="Prediccion")+
  theme_minimal()

ggplot(preds,aes(log(SalePrice),log(P_real)))+geom_point(alpha=0.5,color="dodgerblue")+
  geom_smooth(method = "lm",formula=y~x,color="black",fill="red")+
  geom_abline(slope = 1,intercept = 0,color="red",linetype="dashed",size=1)+
  labs(title = "comparacion:Real vs Predicho",x="Valor Real",y="Prediccion")+
  theme_minimal()
#analisando valores a mas de 5 desviaciones estandar 
print(fit_i%>%extract_recipe()%>%summary()%>%pull(variable))
variables_numericas<-c("MSSubClass","MasVnrArea","GarageCars","OverallCond_grupo","LotFrontage",
                       "GrLivArea","WoodDeckSF","PoolArea","Fireplaces","LotArea","OverallQual",
                       "GarageYrBlt","GarageYrBlt","MiscVal")
vars_categoricas_top<-c("Neighborhood","ExterQual","BsmtQual","KitchenQual","GarageFinish")
df_analisis<-Train_filtrado%>%select(all_of(variables_numericas),all_of(vars_categoricas_top))
df_analisis<-df_analisis%>%mutate(Res_std=data_analisis$Residuo_std)
view(df_analisis%>%filter(abs(Res_std)>=5))
#quitar esos valores y reentrenar el modelo 
train_sin_atipicos<-Train_filtrado
train_sin_atipicos<-train_sin_atipicos%>%mutate(Res_std=df_analisis$Res_std)%>%filter(abs(Res_std)<=5)
train_sin_atipicos<-train_sin_atipicos%>%select(-Res_std)
#entrenar y evaluar
receta_SA<-recipe(SalePrice~.,data = train_sin_atipicos)%>%step_log(all_outcomes(),skip = TRUE)%>%
  step_log(LotArea)%>%
  step_rename(Flr1_sl=`1stFlrSF`,Flr2_SF=`2ndFlrSF`)%>%step_mutate(
    Age_House=YrSold-YearBuilt,Total_porch=OpenPorchSF+EnclosedPorch+ScreenPorch+`3SsnPorch`,
    Has_porch=ifelse(Total_porch>0,1,0),TotalBath=BsmtFullBath+FullBath+0.5*BsmtHalfBath+0.5*HalfBath,
    has_fireplaces=ifelse(FirePlaces>0,1,0))%>%
  step_select(all_numeric_predictors(),all_of(vars_categoricas_top),has_role("outcome"),skip = TRUE)%>%
  step_other(Neighborhood,threshold = 0.005)%>%
  step_string2factor(all_of(vars_categoricas_top))%>%
  step_dummy(all_of(vars_categoricas_top))%>%
  step_rm(any_of(c("YearBuilt","YearRemodAdd","YrSold","Flr1_sl","Flr2_SF","TotalBsmtSF",
                   "Id","OverallCond","GarageArea","Total_porch","OpenPorchSF",
                   "EnclosedPorch","ScreenPorch","3SsnPorch","MoSold","BsmtFullBath",
                   "FullBath","BsmtHalfBath","HalfBath","BsmtFinSF1",
                   "BsmtFinSF2","BsmtUnfSF","LowQualFinSF",
                   "TotRmsAbvGrd","KitchenAbvGr","BedroomAbvGr","FirePlaces")))%>%step_corr(
                     all_numeric_predictors(),threshold = 0.8)%>%step_normalize(all_numeric_predictors())

house_workflow_SA<-workflow()%>%add_recipe(receta_SA)%>%add_model(modelo_lr)
fit_sin_atipicos<-house_workflow_SA%>%fit(data = train_sin_atipicos)
print(tidy(fit_sin_atipicos)%>%arrange(desc(abs(estimate))),n=33)
#metricas de desempeno
print(glance(fit_sin_atipicos))
print(fit_i%>%extract_recipe()%>%summary()%>%filter(role=="predictor"),n=32)
#error cuadratico medio 
ic_train_SA<-predict(fit_sin_atipicos,new_data = train_sin_atipicos,type = "pred_int")

predicciones_sin_atipicos<-exp(predict(fit_sin_atipicos,new_data = train_sin_atipicos))%>%
  bind_cols(train_sin_atipicos%>%select(SalePrice))
predicciones_sin_atipicos<-predicciones_sin_atipicos%>%mutate(Upper=exp(ic_train_SA$.pred_upper),Lower=exp(
  ic_train_SA$.pred_lower))
predicciones_sin_atipicos<-predicciones_sin_atipicos%>%mutate(
  inside=ifelse((SalePrice<=Upper & SalePrice>=Lower),"Yes","NO"))
table(predicciones_sin_atipicos$inside)
print(predicciones_sin_atipicos%>%metrics(truth = SalePrice,estimate = .pred))
ggplot(predicciones_sin_atipicos,aes(SalePrice,.pred))+
  geom_ribbon(aes(ymin = Lower,ymax = Upper),fill="orange",alpha=0.2)+
  geom_point(aes(color=inside),alpha=0.6)+scale_color_manual(values=c("Yes"="darkgreen",
                                                                      "NO"="red"))+
  geom_abline(slope = 1,intercept = 0,linetype="dashed")+
  labs(title = "Intervalo de prediccion(95%)",
       x="Real",y="Predicho")+theme_classic()
#haciedo el fold validacion 

set.seed(42)
final_cv_SA<-fit_resamples(house_workflow_SA,
                        resamples = vfold_cv(train_sin_atipicos,v=15),
                        metrics = metric_set(rmse,rsq,mae),
                        control = control_resamples(save_pred = TRUE))
collect_metrics(final_cv_SA)
preds_SA<-final_cv_SA%>%unnest(.predictions)
preds_SA<-preds_SA%>%select(SalePrice,Predit=.pred)
preds_SA$P_real<-exp(preds_SA$Predit)
print(preds_SA%>%metrics(truth=SalePrice,estimate=P_real))
#probando con el set de test
predic_test<-predict(fit_sin_atipicos,new_data = Prueba_limpio)
sample_submission<-as.data.frame(Prueba_limpio$Id)
sample_submission$SalePrice<-exp(predic_test$.pred)
sample_submission$SalePrice<-exp(predic_test$.pred)
sample_submission<-sample_submission%>%transmute(Id=`Prueba_limpio$Id`,SalePrice)
colSums(is.na(sample_submission))
sample_submission<-sample_submission%>%mutate(
  SalePrice=replace_na(SalePrice,158735.2))
library(writexl)
write_xlsx(sample_submission,"sample_submission_3.xlsx")
#proabando modelo Elastic net 
eln_spec<-linear_reg(penalty = 0.0000000001,mixture = 1)%>%set_engine("glmnet")%>%
  set_mode("regression")
eln_workflow<-workflow()%>%add_recipe(receta_SA)%>%add_model(eln_spec)
#para evaluar en los 15 fold
set.seed(45)
eln_res<-eln_workflow%>%fit_resamples(resamples = vfold_cv(train_sin_atipicos,v=15),
                                      metrics = metric_set(rmse,rsq,mae),
                                      control = control_resamples(save_pred = TRUE))
collect_metrics(eln_res)
p<-eln_res%>%collect_predictions()
p<-p%>%mutate(Pr=exp(.pred))
print(p%>%metrics(truth = SalePrice,estimate = Pr))
#tuning
eln_esp_tune<-linear_reg(penalty = tune(),mixture = tune())%>%
  set_engine("glmnet")%>%set_mode("regression")
eln_grid<-grid_regular(penalty(),mixture(),levels = 5)
tune_result<-workflow()%>%add_recipe(receta_SA)%>%add_model(eln_esp_tune)%>%
  tune_grid(resamples=vfold_cv(train_sin_atipicos,v=15),grid=eln_grid,
            control=control_grid(save_pred = TRUE))
show_best(tune_result)
