packages <- c("tidyverse","tidymodels","nortest","kableExtra","ltm","patchwork",
              "gridExtra","rmarkdown","knitr","xgboost","glmnet","vip","car","writexl")
missing <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if (length(missing)) install.packages(missing,repos="https://cloud.r-project.org")
