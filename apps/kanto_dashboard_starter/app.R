library(shiny)
library(bslib)
library(dplyr)
library(sf)
library(leaflet)

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
    "Run Chapter 7 first and create data_clean/kanto_dashboard_data.rds."
  )
}

bundle <- readRDS(data_path)
pref_geometry <- bundle$pref_geometry
pref_panel <- bundle$pref_panel

pref_choices <- stats::setNames(pref_geometry$code, pref_geometry$pref)
year_choices <- sort(unique(pref_panel$year))

ui <- page_sidebar(
  title = "関東地域ダッシュボード - Starter",
  sidebar = sidebar(
    selectInput(
      "year",
      "年",
      choices = year_choices,
      selected = max(year_choices)
    ),
    selectInput(
      "pref_code",
      "都県",
      choices = pref_choices,
      selected = "13"
    )
  ),
  card(
    full_screen = TRUE,
    card_header("地図"),
    leafletOutput("map", height = "650px")
  )
)

server <- function(input, output, session) {
  map_data <- reactive({
    pref_geometry |>
      left_join(
        pref_panel |>
          filter(year == as.integer(input$year)),
        by = join_by(code, pref),
        relationship = "one-to-one"
      )
  })

  output$map <- renderLeaflet({
    leaflet(map_data()) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      addPolygons(
        fillColor = "#9ecae1",
        fillOpacity = 0.7,
        color = "white",
        weight = 1,
        layerId = ~code,
        label = ~pref
      )
  })

  observeEvent(input$map_shape_click, {
    updateSelectInput(
      session,
      "pref_code",
      selected = input$map_shape_click$id
    )
  })
}

shinyApp(ui, server)
