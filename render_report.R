# Render the original analysis with portable input paths, without changing its models.
if (!requireNamespace("rmarkdown",quietly=TRUE)) stop("Run install_dependencies.R first.")
dir.create("outputs/report",recursive=TRUE,showWarnings=FALSE)
rmarkdown::render("analysis/House_Prices.Rmd",output_format="html_document",
                  output_dir=normalizePath("outputs/report"),knit_root_dir=getwd(),
                  envir=new.env(parent=globalenv()))
