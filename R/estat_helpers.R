# e-Stat API 3.0をRから扱うための講義用ヘルパー -------------------------
# 依存パッケージ: httr2, tibble, dplyr, purrr, readr, jsonlite

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

estat_node_text <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.list(x) && !is.null(x[["$"]])) return(as.character(x[["$"]]))
  as.character(x)[1]
}

# JSONでは、要素が1件のときはnamed list、複数件のときはlist of listsに
# なるため、常にlist of recordsへ正規化する。
estat_records <- function(x) {
  if (is.null(x)) return(list())
  if (!is.list(x)) return(list(x))

  record_markers <- c("@id", "@code", "@name", "@level", "$")
  if (!is.null(names(x)) && any(record_markers %in% names(x))) {
    return(list(x))
  }

  x
}

estat_request <- function(endpoint, ..., app_id = Sys.getenv("ESTAT_APP_ID")) {
  if (!nzchar(app_id)) {
    stop(
      "ESTAT_APP_IDが設定されていません。",
      " .Renviron.exampleを参考にプロジェクト直下へ.Renvironを作成し、Rを再起動してください。",
      call. = FALSE
    )
  }

  base_url <- paste0(
    "https://api.e-stat.go.jp/rest/3.0/app/json/",
    endpoint
  )

  query <- c(list(appId = app_id, lang = "J"), list(...))

  req <- httr2::request(base_url)
  req <- do.call(httr2::req_url_query, c(list(req), query))
  req <- req |>
    httr2::req_user_agent("university-r-course-2026") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(seconds = 60)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)

  root_name <- names(body)[1]
  root <- body[[root_name]]
  status <- suppressWarnings(as.integer(estat_node_text(root$RESULT$STATUS)))
  message_text <- estat_node_text(root$RESULT$ERROR_MSG)

  if (is.na(status) || status >= 100) {
    stop("e-Stat API error [", status, "]: ", message_text, call. = FALSE)
  }
  if (status %in% c(1L, 2L)) warning(message_text, call. = FALSE)

  root
}

estat_search_table <- function(search_word, limit = 100L, ...) {
  root <- estat_request(
    "getStatsList",
    searchWord = search_word,
    limit = limit,
    explanationGetFlg = "N",
    ...
  )

  tables <- estat_records(root$DATALIST_INF$TABLE_INF)

  purrr::map(tables, function(x) {
    tibble::tibble(
      stats_data_id = estat_node_text(x[["@id"]]),
      stat_name = estat_node_text(x$STAT_NAME),
      title = estat_node_text(x$TITLE),
      cycle = estat_node_text(x$CYCLE),
      survey_date = estat_node_text(x$SURVEY_DATE),
      open_date = estat_node_text(x$OPEN_DATE),
      updated_date = estat_node_text(x$UPDATED_DATE),
      collect_area = estat_node_text(x$COLLECT_AREA)
    )
  }) |>
    purrr::list_rbind()
}

estat_get_metadata <- function(stats_data_id) {
  estat_request(
    "getMetaInfo",
    statsDataId = stats_data_id,
    explanationGetFlg = "N"
  )
}

estat_extract_codebook <- function(root) {
  class_inf <- root$METADATA_INF$CLASS_INF %||%
    root$STATISTICAL_DATA$CLASS_INF
  objects <- estat_records(class_inf$CLASS_OBJ)

  purrr::map(objects, function(obj) {
    classes <- estat_records(obj$CLASS)

    purrr::map(classes, function(cls) {
      tibble::tibble(
        dimension_id = estat_node_text(obj[["@id"]]),
        dimension_name = estat_node_text(obj[["@name"]]),
        code = estat_node_text(cls[["@code"]]),
        label = estat_node_text(cls[["@name"]]),
        level = estat_node_text(cls[["@level"]]),
        unit = estat_node_text(cls[["@unit"]]),
        parent_code = estat_node_text(cls[["@parentCode"]])
      )
    }) |>
      purrr::list_rbind()
  }) |>
    purrr::list_rbind()
}

estat_get_data_page <- function(
    stats_data_id,
    start_position = 1L,
    limit = 100000L,
    meta_get = TRUE,
    ...) {
  estat_request(
    "getStatsData",
    statsDataId = stats_data_id,
    startPosition = start_position,
    limit = limit,
    metaGetFlg = if (meta_get) "Y" else "N",
    annotationGetFlg = "Y",
    ...
  )
}

estat_extract_values <- function(root) {
  values <- estat_records(root$STATISTICAL_DATA$DATA_INF$VALUE)

  purrr::map(values, function(value_node) {
    attrs <- value_node[startsWith(names(value_node), "@")]
    names(attrs) <- sub("^@", "", names(attrs))

    out <- tibble::as_tibble(attrs)
    out$value_raw <- estat_node_text(value_node)
    out
  }) |>
    purrr::list_rbind() |>
    dplyr::mutate(
      value = readr::parse_number(
        .data$value_raw,
        na = c("", "-", "...", "X")
      )
    )
}

estat_add_labels <- function(data, codebook) {
  dimensions <- intersect(unique(codebook$dimension_id), names(data))

  purrr::reduce(
    dimensions,
    .init = data,
    .f = function(acc, dimension_id) {
      lookup <- codebook |>
        dplyr::filter(.data$dimension_id == dimension_id) |>
        dplyr::select(.data$code, .data$label) |>
        dplyr::distinct()

      names(lookup) <- c(dimension_id, paste0(dimension_id, "_label"))
      dplyr::left_join(acc, lookup, by = dimension_id)
    }
  )
}

# ラベル名がどの次元（cat01, cat02, area, timeなど）に入っているかを
# 決め打ちせず、該当ラベルを含む行だけを残す。
# メタデータを確認した後の教材用抽出に使う。
estat_filter_label <- function(data, label) {
  label_columns <- names(data)[endsWith(names(data), "_label")]

  if (length(label_columns) == 0) {
    stop("ラベル列がありません。estat_add_labels()を先に実行してください。", call. = FALSE)
  }

  matches <- purrr::map(
    data[label_columns],
    ~ dplyr::coalesce(as.character(.x) == label, FALSE)
  )

  matched_columns <- names(matches)[purrr::map_lgl(matches, any)]
  if (length(matched_columns) == 0) {
    stop(
      "ラベル '", label, "' が見つかりません。コード表を確認してください。",
      call. = FALSE
    )
  }

  keep <- purrr::reduce(matches, `|`)
  data[keep, , drop = FALSE]
}

estat_get_all_pages <- function(
    stats_data_id,
    limit = 100000L,
    max_pages = 100L,
    ...) {
  pages <- list()
  start_position <- 1L

  for (i in seq_len(max_pages)) {
    root <- estat_get_data_page(
      stats_data_id = stats_data_id,
      start_position = start_position,
      limit = limit,
      meta_get = i == 1L,
      ...
    )
    pages[[i]] <- root

    next_key <- estat_node_text(root$STATISTICAL_DATA$RESULT_INF$NEXT_KEY)
    if (is.na(next_key) || !nzchar(next_key)) break
    start_position <- as.integer(next_key)
  }

  if (length(pages) == max_pages && !is.na(next_key) && nzchar(next_key)) {
    stop("max_pagesに達しました。取得条件または上限を確認してください。")
  }

  pages
}


estat_download <- function(
    stats_data_id,
    limit = 100000L,
    max_pages = 100L,
    ...) {
  query <- list(...)
  metadata <- estat_get_metadata(stats_data_id)
  codebook <- estat_extract_codebook(metadata)
  pages <- estat_get_all_pages(
    stats_data_id = stats_data_id,
    limit = limit,
    max_pages = max_pages,
    ...
  )

  values <- purrr::map(pages, estat_extract_values) |>
    purrr::list_rbind()

  if (is.null(values)) values <- tibble::tibble()

  labeled <- if (nrow(values) > 0) {
    estat_add_labels(values, codebook)
  } else {
    values
  }

  structure(
    list(
      stats_data_id = stats_data_id,
      retrieved_at = format(Sys.time(), tz = "Asia/Tokyo", usetz = TRUE),
      query = query,
      metadata = metadata,
      codebook = codebook,
      pages = pages,
      values = values,
      data = labeled
    ),
    class = "estat_download"
  )
}

estat_save_download <- function(
    download,
    stem,
    raw_dir = file.path("data_raw", "estat"),
    clean_dir = "data_clean") {
  stopifnot(inherits(download, "estat_download"))
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)

  safe_stem <- gsub("[^A-Za-z0-9_-]+", "_", stem)
  raw_json <- file.path(raw_dir, paste0(safe_stem, "_response.json"))
  raw_rds <- file.path(raw_dir, paste0(safe_stem, "_response.rds"))
  data_rds <- file.path(clean_dir, paste0(safe_stem, ".rds"))
  data_csv <- file.path(clean_dir, paste0(safe_stem, ".csv"))
  codebook_csv <- file.path(clean_dir, paste0(safe_stem, "_codebook.csv"))
  log_csv <- file.path(clean_dir, paste0(safe_stem, "_download_log.csv"))

  raw_response <- list(
    stats_data_id = download$stats_data_id,
    retrieved_at = download$retrieved_at,
    query = download$query,
    metadata = download$metadata,
    pages = download$pages
  )

  # JSONはR以外でも確認しやすく、RDSはRの型を保ったまま再利用しやすい。
  jsonlite::write_json(
    raw_response,
    path = raw_json,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    na = "null"
  )
  saveRDS(raw_response, raw_rds)
  saveRDS(download$data, data_rds)
  readr::write_csv(download$data, data_csv, na = "")
  readr::write_csv(download$codebook, codebook_csv, na = "")

  query_text <- if (length(download$query) == 0) {
    ""
  } else {
    paste(
      paste(names(download$query), unlist(download$query), sep = "="),
      collapse = "&"
    )
  }

  log <- tibble::tibble(
    source = "e-Stat API 3.0",
    stats_data_id = download$stats_data_id,
    retrieved_at = download$retrieved_at,
    query = query_text,
    page_count = length(download$pages),
    row_count = nrow(download$data)
  )
  readr::write_csv(log, log_csv, na = "")

  tibble::tibble(
    artifact = c(
      "raw_response_json", "raw_response_rds", "data_rds",
      "data_csv", "codebook", "download_log"
    ),
    path = c(
      raw_json, raw_rds, data_rds,
      data_csv, codebook_csv, log_csv
    )
  )
}
