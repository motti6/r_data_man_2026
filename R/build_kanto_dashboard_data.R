# Build the spatial data bundle used by the Chapter 8 Shiny app.
# Run from the project root after downloading and unzipping the KSJ files.

build_kanto_dashboard_data <- function(
  n03_dir = file.path("data_raw", "ksj", "n03_kanto"),
  s12_dir = file.path("data_raw", "ksj", "s12_station"),
  pref_data_path = file.path("data_raw", "c_pref_gdp.xlsx"),
  population_path = file.path("data_clean", "pref_population_2020.csv"),
  output_path = file.path("data_clean", "kanto_dashboard_data.rds"),
  gpkg_path = file.path("data_clean", "kanto_spatial.gpkg")
) {
  required_packages <- c(
    "dplyr", "tidyr", "stringr", "readr", "readxl", "sf", "units", "scales"
  )

  package_status <- vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )

  if (!all(package_status)) {
    stop(
      "Missing packages: ",
      paste(names(package_status)[!package_status], collapse = ", "),
      ". Run source('setup_packages.R') first."
    )
  }

  source(file.path("R", "spatial_helpers.R"), local = TRUE)

  if (!file.exists(pref_data_path)) {
    stop("Prefecture data file not found: ", pref_data_path)
  }

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

  # ---------------------------------------------------------------------------
  # 1. Administrative boundaries: dissolve municipality polygons to prefecture.
  # ---------------------------------------------------------------------------
  n03_file <- find_spatial_file(n03_dir, prefix = "N03")
  n03_raw <- sf::st_read(n03_file, quiet = TRUE, stringsAsFactors = FALSE)

  assert_has_columns(
    n03_raw,
    c("N03_001", "N03_004", "N03_007"),
    object_name = "N03 data"
  )

  kanto_codes <- c("08", "09", "10", "11", "12", "13", "14")

  pref_code_map <- readxl::read_excel(pref_data_path, sheet = "gdp") |>
    dplyr::transmute(
      code = pad_pref_code(code),
      pref = as.character(pref)
    ) |>
    dplyr::filter(code %in% kanto_codes) |>
    dplyr::distinct()

  kanto_pref_full_projected <- n03_raw |>
    dplyr::transmute(
      pref = as.character(N03_001),
      municipality = as.character(N03_004),
      local_code = as.character(N03_007)
    ) |>
    dplyr::filter(pref %in% pref_code_map$pref) |>
    sf::st_make_valid() |>
    sf::st_transform(6677) |>
    dplyr::group_by(pref) |>
    dplyr::summarise(.groups = "drop") |>
    dplyr::left_join(
      pref_code_map,
      by = dplyr::join_by(pref),
      relationship = "one-to-one"
    ) |>
    dplyr::select(code, pref, geometry) |>
    dplyr::mutate(
      area_km2 = as.numeric(
        units::set_units(sf::st_area(geometry), km^2)
      )
    )

  if (nrow(kanto_pref_full_projected) != 7) {
    warning(
      "Expected 7 Kanto prefectures, but found ",
      nrow(kanto_pref_full_projected),
      ". Check the selected N03 file."
    )
  }

  # The full Tokyo geometry includes remote islands. Keep the full area value,
  # but crop the display geometry to mainland Kanto so the dashboard is legible.
  mainland_window <- sf::st_bbox(
    c(xmin = 138.2, ymin = 34.9, xmax = 141.1, ymax = 37.3),
    crs = sf::st_crs(4326)
  ) |>
    sf::st_as_sfc() |>
    sf::st_transform(6677)

  kanto_pref_projected <- suppressWarnings(
    sf::st_intersection(kanto_pref_full_projected, mainland_window)
  )

  # Simplify only after dissolving/cropping and in a projected CRS in metres.
  kanto_pref <- kanto_pref_projected |>
    dplyr::mutate(
      geometry = sf::st_simplify(
        geometry,
        preserveTopology = TRUE,
        dTolerance = 250
      )
    ) |>
    sf::st_transform(4326)

  # ---------------------------------------------------------------------------
  # 2. Chapter 6 prefecture panel: GDP and compensation, 2011-2021.
  # ---------------------------------------------------------------------------
  pref_gdp <- read_pref_wide(pref_data_path, "gdp", "gdp")
  pref_compensation <- read_pref_wide(
    pref_data_path,
    "compensation",
    "compensation"
  )

  pref_panel <- pref_gdp |>
    dplyr::inner_join(
      pref_compensation,
      by = dplyr::join_by(code, pref, year),
      relationship = "one-to-one"
    ) |>
    dplyr::mutate(
      compensation_to_gdp = compensation / gdp
    ) |>
    dplyr::semi_join(
      sf::st_drop_geometry(kanto_pref),
      by = dplyr::join_by(code, pref)
    ) |>
    dplyr::arrange(code, year)

  pref_agri <- readxl::read_excel(
    pref_data_path,
    sheet = "agri_forestry"
  ) |>
    dplyr::transmute(
      code = pad_pref_code(code),
      pref = as.character(pref),
      year = as.integer(year),
      agriculture = as.numeric(agriculture),
      forestry = as.numeric(forestry),
      agri_forestry = agriculture + forestry
    ) |>
    dplyr::left_join(
      pref_gdp,
      by = dplyr::join_by(code, pref, year),
      relationship = "many-to-one"
    ) |>
    dplyr::mutate(
      agri_forestry_share = agri_forestry / gdp
    ) |>
    dplyr::semi_join(
      sf::st_drop_geometry(kanto_pref),
      by = dplyr::join_by(code, pref)
    )

  # Optional bridge to Chapter 2: e-Stat prefectural population for 2020.
  if (file.exists(population_path)) {
    pref_population <- readr::read_csv(
      population_path,
      col_types = readr::cols(code = readr::col_character()),
      show_col_types = FALSE
    ) |>
      dplyr::transmute(
        code = pad_pref_code(code),
        pref = as.character(pref),
        population_2020 = as.numeric(population)
      ) |>
      dplyr::distinct(code, .keep_all = TRUE)

    pref_profile <- pref_gdp |>
      dplyr::filter(year == 2020) |>
      dplyr::select(code, pref, gdp_2020 = gdp) |>
      dplyr::left_join(
        pref_population,
        by = dplyr::join_by(code, pref),
        relationship = "one-to-one"
      ) |>
      dplyr::mutate(
        gdp_per_capita_10k_yen_2020 = gdp_2020 * 100 / population_2020
      )
  } else {
    pref_profile <- pref_code_map |>
      dplyr::mutate(
        gdp_2020 = NA_real_,
        population_2020 = NA_real_,
        gdp_per_capita_10k_yen_2020 = NA_real_
      )
  }

  pref_profile <- pref_profile |>
    dplyr::semi_join(
      sf::st_drop_geometry(kanto_pref),
      by = dplyr::join_by(code, pref)
    )

  # ---------------------------------------------------------------------------
  # 3. Station passenger data: aggregate line features to one point per group.
  # ---------------------------------------------------------------------------
  s12_file <- find_spatial_file(s12_dir, prefix = "S12")
  s12_raw <- sf::st_read(s12_file, quiet = TRUE, stringsAsFactors = FALSE)

  assert_has_columns(
    s12_raw,
    c(
      "S12_001", "S12_001g", "S12_002", "S12_003",
      "S12_059", "S12_061"
    ),
    object_name = "S12 data"
  )

  station_lines <- s12_raw |>
    dplyr::transmute(
      station_name = as.character(S12_001),
      station_group = as.character(S12_001g),
      operator = as.character(S12_002),
      line_name = as.character(S12_003),
      data_status_2024 = as.character(S12_059),
      passengers_2024 = suppressWarnings(as.numeric(S12_061))
    ) |>
    dplyr::filter(
      !is.na(station_group),
      !is.na(passengers_2024),
      passengers_2024 >= 0
    ) |>
    sf::st_make_valid() |>
    sf::st_transform(6677)

  station_points_projected <- station_lines |>
    dplyr::group_by(station_group, station_name) |>
    dplyr::summarise(
      passengers_2024 = max(passengers_2024, na.rm = TRUE),
      operator = paste(
        sort(unique(stats::na.omit(operator))),
        collapse = " / "
      ),
      line_name = paste(
        sort(unique(stats::na.omit(line_name))),
        collapse = " / "
      ),
      .groups = "drop"
    ) |>
    sf::st_centroid()

  station_points <- station_points_projected |>
    sf::st_join(
      kanto_pref_projected |>
        dplyr::select(pref_code = code, pref),
      join = sf::st_within,
      left = FALSE
    ) |>
    dplyr::arrange(dplyr::desc(passengers_2024)) |>
    dplyr::distinct(station_group, .keep_all = TRUE) |>
    sf::st_transform(4326)

  # ---------------------------------------------------------------------------
  # 4. Save one RDS for Shiny and one GeoPackage for interoperability.
  # ---------------------------------------------------------------------------
  bundle <- list(
    pref_geometry = kanto_pref,
    pref_panel = pref_panel,
    pref_agri = pref_agri,
    pref_profile = pref_profile,
    station_points = station_points,
    metadata = list(
      created_at = format(Sys.time(), tz = "Asia/Tokyo", usetz = TRUE),
      n03_file = basename(n03_file),
      s12_file = basename(s12_file),
      n03_source = paste0(
        "https://nlftp.mlit.go.jp/ksj/gml/datalist/",
        "KsjTmplt-N03-2026.html"
      ),
      s12_source = paste0(
        "https://nlftp.mlit.go.jp/ksj/gml/datalist/",
        "KsjTmplt-S12-2024.html"
      ),
      prefecture_source = "Cabinet Office, Prefectural Accounts, distributed course snapshot",
      population_source = if (file.exists(population_path)) {
        "e-Stat Population Estimates, Chapter 2 output"
      } else {
        "Not included: run Chapter 2 API exercise to create pref_population_2020.csv"
      },
      note = paste(
        "N03 boundaries are cropped to mainland Kanto and simplified for web display; area_km2 is calculated from the full prefecture geometry.",
        "S12 station counts are not compiled under a single operator-wide standard."
      )
    )
  )

  saveRDS(bundle, output_path, compress = "xz")

  if (file.exists(gpkg_path)) {
    unlink(gpkg_path)
  }

  sf::st_write(
    kanto_pref,
    gpkg_path,
    layer = "prefecture",
    quiet = TRUE
  )
  sf::st_write(
    station_points,
    gpkg_path,
    layer = "station_points",
    quiet = TRUE
  )

  message("Saved Shiny data bundle: ", output_path)
  message("Saved GeoPackage: ", gpkg_path)
  message("Prefectures: ", nrow(kanto_pref))
  message("Stations: ", nrow(station_points))

  invisible(bundle)
}
