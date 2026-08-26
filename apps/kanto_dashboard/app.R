library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(sf)
library(leaflet)
library(DT)
library(scales)

project_dir <- normalizePath(
  file.path(getwd(), "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

data_path <- file.path(
  project_dir,
  "data_clean",
  "kanto_dashboard_data.rds"
)

if (!file.exists(data_path)) {
  stop(
    paste(
      "Required file not found:",
      data_path,
      "Run Chapter 7 and create the dashboard data bundle first.",
      sep = "\n"
    )
  )
}

bundle <- readRDS(data_path)
pref_geometry <- bundle$pref_geometry
pref_panel <- bundle$pref_panel
pref_agri <- bundle$pref_agri
pref_profile <- bundle$pref_profile
station_points <- bundle$station_points

if (is.null(pref_profile)) {
  pref_profile <- pref_geometry |>
    st_drop_geometry() |>
    transmute(
      code,
      pref,
      gdp_2020 = NA_real_,
      population_2020 = NA_real_,
      gdp_per_capita_10k_yen_2020 = NA_real_
    )
}

metric_spec <- tibble::tribble(
  ~metric, ~label, ~short_label, ~unit, ~palette,
  "gdp", "県内総生産", "GDP", "百万円", "Blues",
  "compensation", "雇用者報酬", "雇用者報酬", "百万円", "Greens",
  "compensation_to_gdp", "雇用者報酬 / GDP", "雇用者報酬比率", "％", "Purples"
)

metric_choices <- stats::setNames(metric_spec$metric, metric_spec$label)
pref_choices <- stats::setNames(pref_geometry$code, pref_geometry$pref)
year_choices <- sort(unique(pref_panel$year))

station_slider_max <- max(
  100000,
  ceiling(stats::quantile(station_points$passengers_2024, 0.98, na.rm = TRUE) / 10000) * 10000
)
station_slider_default <- min(20000, station_slider_max)

format_dashboard_value <- function(value, metric) {
  if (length(value) == 0 || is.na(value)) {
    return("NA")
  }

  if (metric == "compensation_to_gdp") {
    return(label_percent(accuracy = 0.1)(value))
  }

  label_number(big.mark = ",", accuracy = 1)(value)
}

ui <- page_sidebar(
  title = "関東の地域経済・鉄道ダッシュボード",
  window_title = "関東の地域経済・鉄道ダッシュボード",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2166ac",
    secondary = "#5ab4ac"
  ),
  sidebar = sidebar(
    width = 320,
    selectInput(
      "year",
      "地図の年",
      choices = year_choices,
      selected = max(year_choices)
    ),
    selectInput(
      "metric",
      "地図の指標",
      choices = metric_choices,
      selected = "gdp"
    ),
    selectInput(
      "pref_code",
      "選択する都県",
      choices = pref_choices,
      selected = "13"
    ),
    sliderInput(
      "min_passengers",
      "表示する駅の最小乗降客数（人 / 日）",
      min = 0,
      max = station_slider_max,
      value = station_slider_default,
      step = 5000,
      sep = ","
    ),
    checkboxInput(
      "show_stations",
      "駅を表示する",
      value = TRUE
    ),
    checkboxInput(
      "fixed_scale",
      "年をまたいで色尺度を固定する",
      value = TRUE
    ),
    hr(),
    p(
      class = "text-muted small",
      "地図上の都県をクリックすると選択欄も連動します。"
    ),
    p(
      class = "text-muted small",
      "経済データは2011～2021年、駅別乗降客数は2024年度です。異なる基準年を明示して併記します。"
    )
  ),
  layout_columns(
    col_widths = c(3, 3, 3, 3),
    value_box(
      title = "選択値",
      value = textOutput("selected_value", inline = TRUE),
      showcase = icon("chart-bar"),
      theme = "primary"
    ),
    value_box(
      title = "関東内順位",
      value = textOutput("selected_rank", inline = TRUE),
      showcase = icon("trophy"),
      theme = "info"
    ),
    value_box(
      title = "前年比",
      value = textOutput("selected_yoy", inline = TRUE),
      showcase = icon("arrow-up"),
      theme = "success"
    ),
    value_box(
      title = "条件を満たす駅数",
      value = textOutput("selected_station_count", inline = TRUE),
      showcase = icon("train"),
      theme = "warning"
    )
  ),
  layout_columns(
    col_widths = c(8, 4),
    card(
      full_screen = TRUE,
      card_header(textOutput("map_title", inline = TRUE)),
      leafletOutput("map", height = "610px")
    ),
    card(
      full_screen = TRUE,
      card_header("選択した都県の時系列"),
      plotOutput("trend_plot", height = "310px"),
      hr(),
      uiOutput("profile_text")
    )
  ),
  layout_columns(
    col_widths = c(5, 7),
    card(
      full_screen = TRUE,
      card_header("関東内ランキング"),
      plotOutput("ranking_plot", height = "360px")
    ),
    card(
      full_screen = TRUE,
      card_header("ランキング表"),
      DTOutput("ranking_table")
    )
  ),
  card(
    card_header("出所と解釈上の注意"),
    tags$ul(
      tags$li("行政区域：国土交通省『国土数値情報（行政区域）』N03。"),
      tags$li("駅別乗降客数：国土交通省『国土数値情報（駅別乗降客数）』S12、2024年度。"),
      tags$li("経済指標：内閣府『県民経済計算』の講義用スナップショット。"),
      tags$li("人口：第2章で取得したe-Stat『人口推計』（ファイルがある場合のみ表示）。"),
      tags$li("基準年が異なるデータを意図的に併記しています。同一年の因果比較として解釈しないでください。"),
      tags$li("駅別乗降客数は事業者提供資料に基づき、全事業者共通の算出基準ではありません。")
    )
  )
)

server <- function(input, output, session) {
  selected_spec <- reactive({
    metric_spec |>
      filter(metric == input$metric) |>
      slice(1)
  })

  map_data <- reactive({
    req(input$year, input$metric)

    panel_year <- pref_panel |>
      filter(year == as.integer(input$year))

    result <- pref_geometry |>
      left_join(
        panel_year,
        by = join_by(code, pref),
        relationship = "one-to-one"
      )

    result$map_value <- result[[input$metric]]
    result$map_label <- paste0(
      result$pref,
      "<br>",
      selected_spec()$short_label,
      ": ",
      vapply(
        result$map_value,
        format_dashboard_value,
        character(1),
        metric = input$metric
      )
    )
    result$border_weight <- ifelse(result$code == input$pref_code, 4, 1)

    result
  })

  ranking_data <- reactive({
    map_data() |>
      st_drop_geometry() |>
      arrange(desc(map_value)) |>
      mutate(rank = row_number())
  })

  selected_row <- reactive({
    row <- ranking_data() |>
      filter(code == input$pref_code) |>
      slice(1)

    req(nrow(row) == 1)
    row
  })

  previous_value <- reactive({
    previous_year <- as.integer(input$year) - 1L

    pref_panel |>
      filter(
        code == input$pref_code,
        year == previous_year
      ) |>
      pull(all_of(input$metric)) |>
      dplyr::first(default = NA_real_)
  })

  filtered_stations <- reactive({
    station_points |>
      filter(passengers_2024 >= input$min_passengers) |>
      mutate(
        marker_radius = pmax(
          3,
          pmin(13, sqrt(passengers_2024) / 45)
        ),
        station_label = paste0(
          station_name,
          "<br>",
          format(passengers_2024, big.mark = ","),
          " 人 / 日",
          "<br>",
          line_name
        )
      )
  })

  output$map <- renderLeaflet({
    bbox <- st_bbox(pref_geometry)

    leaflet(options = leafletOptions(preferCanvas = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      fitBounds(
        lng1 = bbox[["xmin"]],
        lat1 = bbox[["ymin"]],
        lng2 = bbox[["xmax"]],
        lat2 = bbox[["ymax"]]
      )
  })

  observe({
    current_map <- map_data()
    spec <- selected_spec()

    palette_domain <- if (isTRUE(input$fixed_scale)) {
      pref_panel[[input$metric]]
    } else {
      current_map$map_value
    }

    palette <- colorNumeric(
      palette = spec$palette,
      domain = palette_domain,
      na.color = "#d9d9d9"
    )

    leafletProxy("map", data = current_map) |>
      clearGroup("prefectures") |>
      clearControls() |>
      addPolygons(
        group = "prefectures",
        layerId = ~code,
        fillColor = ~palette(map_value),
        fillOpacity = 0.78,
        color = "#ffffff",
        weight = ~border_weight,
        opacity = 1,
        label = ~lapply(map_label, htmltools::HTML),
        highlightOptions = highlightOptions(
          weight = 4,
          color = "#222222",
          bringToFront = TRUE
        )
      ) |>
      addLegend(
        position = "bottomright",
        pal = palette,
        values = ~map_value,
        title = paste0(
          spec$short_label,
          " (",
          input$year,
          if (isTRUE(input$fixed_scale)) "・尺度固定" else "",
          ")"
        ),
        opacity = 0.9
      )
  })

  observe({
    proxy <- leafletProxy("map") |>
      clearGroup("stations")

    if (isTRUE(input$show_stations)) {
      stations <- filtered_stations()

      if (nrow(stations) > 0) {
        proxy |>
          addCircleMarkers(
            data = stations,
            group = "stations",
            radius = ~marker_radius,
            color = "#8c2d04",
            weight = 1,
            fillColor = "#fe9929",
            fillOpacity = 0.75,
            label = ~lapply(station_label, htmltools::HTML)
          )
      }
    }
  })

  observeEvent(input$map_shape_click, {
    clicked_code <- input$map_shape_click$id

    if (!is.null(clicked_code) && clicked_code %in% pref_geometry$code) {
      updateSelectInput(
        session,
        "pref_code",
        selected = clicked_code
      )
    }
  })

  output$map_title <- renderText({
    paste0(
      input$year,
      "年 ",
      selected_spec()$label,
      "（都県別）"
    )
  })

  output$selected_value <- renderText({
    row <- selected_row()
    format_dashboard_value(row$map_value, input$metric)
  })

  output$selected_rank <- renderText({
    row <- selected_row()
    paste0(row$rank, " / ", nrow(ranking_data()))
  })

  output$selected_yoy <- renderText({
    row <- selected_row()
    previous <- previous_value()

    if (is.na(previous) || previous == 0) {
      return("NA")
    }

    label_percent(accuracy = 0.1)(row$map_value / previous - 1)
  })

  output$selected_station_count <- renderText({
    station_count <- filtered_stations() |>
      filter(pref_code == input$pref_code) |>
      nrow()

    label_number(big.mark = ",", accuracy = 1)(station_count)
  })

  output$trend_plot <- renderPlot({
    selected_pref <- pref_geometry |>
      st_drop_geometry() |>
      filter(code == input$pref_code) |>
      pull(pref) |>
      first()

    trend <- pref_panel |>
      filter(code == input$pref_code) |>
      select(year, gdp, compensation) |>
      pivot_longer(
        cols = c(gdp, compensation),
        names_to = "series",
        values_to = "value"
      ) |>
      mutate(
        series = recode(
          series,
          gdp = "県内総生産",
          compensation = "雇用者報酬"
        )
      )

    ggplot(trend, aes(x = year, y = value, color = series)) +
      geom_line(linewidth = 1.1) +
      geom_point(size = 2) +
      scale_x_continuous(breaks = sort(unique(trend$year))) +
      scale_y_continuous(labels = label_number(big.mark = ",")) +
      labs(
        title = selected_pref,
        x = NULL,
        y = "百万円",
        color = NULL
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
  })

  output$profile_text <- renderUI({
    agri_row <- pref_agri |>
      filter(code == input$pref_code, year == 2021) |>
      slice(1)

    profile_row <- pref_profile |>
      filter(code == input$pref_code) |>
      slice(1)

    station_total <- station_points |>
      filter(pref_code == input$pref_code) |>
      nrow()

    if (nrow(agri_row) == 0) {
      agri_label <- "農林業シェア：NA"
    } else {
      agri_label <- paste0(
        "2021年の農林業シェア：",
        label_percent(accuracy = 0.1)(agri_row$agri_forestry_share)
      )
    }

    if (nrow(profile_row) == 0 || is.na(profile_row$population_2020)) {
      population_label <- "2020年人口・一人当たりGDP：第2章のAPI取得結果なし"
    } else {
      population_label <- paste0(
        "2020年人口：",
        label_number(big.mark = ",", accuracy = 1)(profile_row$population_2020),
        "人 ／ 一人当たりGDP：",
        label_number(big.mark = ",", accuracy = 0.1)(
          profile_row$gdp_per_capita_10k_yen_2020
        ),
        "万円"
      )
    }

    tagList(
      p(strong(selected_row()$pref)),
      p(population_label),
      p(agri_label),
      p(
        paste0(
          "2024年度の乗降客数が収録されている駅：",
          format(station_total, big.mark = ",")
        )
      ),
      p(
        class = "text-muted small",
        "駅のしきい値は地図とKPIにのみ反映され、この総数には反映されません。"
      )
    )
  })

  output$ranking_plot <- renderPlot({
    plot_data <- ranking_data() |>
      mutate(selected = code == input$pref_code)

    ggplot(
      plot_data,
      aes(
        x = reorder(pref, map_value),
        y = map_value,
        fill = selected
      )
    ) +
      geom_col() +
      coord_flip() +
      scale_fill_manual(
        values = c(`FALSE` = "#bdbdbd", `TRUE` = "#2166ac"),
        guide = "none"
      ) +
      scale_y_continuous(
        labels = if (input$metric == "compensation_to_gdp") {
          label_percent(accuracy = 1)
        } else {
          label_number(big.mark = ",")
        }
      ) +
      labs(
        x = NULL,
        y = selected_spec()$unit
      ) +
      theme_minimal(base_size = 12)
  })

  output$ranking_table <- renderDT({
    table_data <- ranking_data() |>
      transmute(
        rank,
        prefecture = pref,
        value = map_value
      )

    table_widget <- datatable(
      table_data,
      rownames = FALSE,
      selection = "none",
      options = list(
        pageLength = 7,
        lengthChange = FALSE,
        searching = FALSE,
        ordering = FALSE,
        dom = "t"
      )
    )

    if (input$metric == "compensation_to_gdp") {
      formatPercentage(table_widget, "value", digits = 1)
    } else {
      formatRound(table_widget, "value", digits = 0, mark = ",")
    }
  })
}

shinyApp(ui, server)
