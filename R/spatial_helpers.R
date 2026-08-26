# Generic helpers used in Chapters 7 and 8.
# Technical identifiers and file names are intentionally ASCII-only.

find_spatial_file <- function(root, prefix = NULL) {
  if (!dir.exists(root)) {
    stop("Directory not found: ", root)
  }

  candidates <- list.files(
    root,
    pattern = "\\.(shp|geojson|gpkg)$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  if (!is.null(prefix)) {
    candidates <- candidates[
      stringr::str_detect(
        basename(candidates),
        stringr::regex(paste0("^", prefix), ignore_case = TRUE)
      )
    ]
  }

  if (length(candidates) == 0) {
    stop(
      "No spatial file was found under ", root,
      if (!is.null(prefix)) paste0(" with prefix ", prefix) else "",
      ". Unzip the downloaded KSJ file first."
    )
  }

  # Prefer shapefile, then GeoJSON, then GeoPackage when multiple files exist.
  extension_rank <- match(
    tolower(tools::file_ext(candidates)),
    c("shp", "geojson", "gpkg")
  )
  candidates <- candidates[order(extension_rank, nchar(candidates), candidates)]

  if (length(candidates) > 1) {
    message(
      "Multiple spatial files were found. The first candidate is used:\n",
      paste0("- ", candidates, collapse = "\n")
    )
  }

  candidates[[1]]
}

assert_has_columns <- function(data, required, object_name = deparse(substitute(data))) {
  missing_columns <- setdiff(required, names(data))

  if (length(missing_columns) > 0) {
    stop(
      object_name,
      " is missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }

  invisible(TRUE)
}

pad_pref_code <- function(x) {
  stringr::str_pad(as.character(x), width = 2, side = "left", pad = "0")
}

read_pref_wide <- function(path, sheet, value_name) {
  data <- readxl::read_excel(path, sheet = sheet) |>
    dplyr::select(code, pref, dplyr::matches("^\\d{4}$")) |>
    dplyr::mutate(code = pad_pref_code(code)) |>
    tidyr::pivot_longer(
      cols = dplyr::matches("^\\d{4}$"),
      names_to = "year",
      values_to = value_name,
      names_transform = list(year = as.integer)
    )

  duplicate_keys <- data |>
    dplyr::count(code, year) |>
    dplyr::filter(n > 1)

  if (nrow(duplicate_keys) > 0) {
    stop("Duplicate prefecture-year keys were found in sheet: ", sheet)
  }

  data
}

format_metric_value <- function(value, metric) {
  if (length(value) == 0 || is.na(value)) {
    return("NA")
  }

  switch(
    metric,
    gdp = scales::label_number(big.mark = ",", accuracy = 1)(value),
    compensation = scales::label_number(big.mark = ",", accuracy = 1)(value),
    compensation_to_gdp = scales::label_percent(accuracy = 0.1)(value),
    scales::label_number(big.mark = ",", accuracy = 0.1)(value)
  )
}
