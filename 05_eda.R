source("00_config.R")
if (!file.exists(train_path)) stop("Download train.csv as described in data/raw/README.md")
d <- readr::read_csv(train_path, show_col_types=FALSE)
stopifnot(nrow(d)==1460L,all(d$SalePrice>0))
write_table(d %>% summarise(n=n(),minimum=min(SalePrice),median=median(SalePrice),maximum=max(SalePrice)),"descriptive_prices.csv")
save_plot(ggplot(d,aes(SalePrice))+geom_histogram(binwidth=50000,boundary=0,fill="steelblue",color="white")+
 theme_bw()+labs(x="Sale price (USD)",y="Houses"),"price_distribution.png")
save_plot(ggplot(d,aes(GrLivArea,SalePrice))+geom_point(alpha=.4,color="steelblue")+
 theme_bw()+labs(x="Above-ground living area (square feet)",y="Sale price (USD)"),"living_area_vs_price.png")
