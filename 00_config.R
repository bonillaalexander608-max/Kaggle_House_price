packages <- c("tidyverse", "tidymodels", "xgboost", "digest")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Run source('install_dependencies.R') first.")
suppressPackageStartupMessages({library(tidyverse); library(tidymodels)})
cfg <- list(seed_split = 123L, seed_folds = 26L, seed_grid = 2026L,
            seed_fit = 2027L, seed_boot = 2028L, prop_train = .8,
            folds = 5L, grid_size = 20L, B = 2000L, linear_weight = .6)
train_path <- file.path("data", "raw", "train.csv")
test_path <- file.path("data", "raw", "test.csv")
run_dir <- file.path("outputs", "run_v1")
for (s in c("models", "tables", "figures")) dir.create(file.path(run_dir,s),recursive=TRUE,showWarnings=FALSE)
write_table <- function(x,n) readr::write_csv(x,file.path(run_dir,"tables",n))
save_plot <- function(p,n) ggplot2::ggsave(file.path(run_dir,"figures",n),p,width=9,height=6,dpi=300,bg="white")
