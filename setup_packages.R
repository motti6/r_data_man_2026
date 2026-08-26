required_packages <- c(
  "knitr", "rmarkdown", "yaml",
  "tidyverse", "readxl", "writexl", "lubridate",
  "httr2", "jsonlite", "scales",
  "sf", "units", "leaflet", "shiny", "bslib", "DT"
)

installed <- rownames(installed.packages())
missing_packages <- setdiff(required_packages, installed)
is_renv_project <- file.exists("renv/activate.R") || file.exists("renv.lock")

if (length(missing_packages) == 0) {
  message("必要なパッケージはすべてインストール済みです。")
} else if (is_renv_project && requireNamespace("renv", quietly = TRUE)) {
  message("renvプロジェクトとして不足パッケージを導入します。")
  renv::install(missing_packages)
  renv::snapshot()
} else {
  message("通常のRライブラリへ不足パッケージを導入します。")
  install.packages(missing_packages)
}

status <- vapply(
  required_packages,
  requireNamespace,
  quietly = TRUE,
  FUN.VALUE = logical(1)
)

print(status)

if (!all(status)) {
  stop(
    "一部のパッケージを読み込めません。上のFALSEになったパッケージと、",
    "インストール時のエラーを確認してください。"
  )
}
