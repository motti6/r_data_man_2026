# Kanto economy and rail dashboard

This is the completed Shiny app used in Chapter 8.

## Prerequisite

Chapter 7 must create:

```text
data_clean/kanto_dashboard_data.rds
```

From the project root:

```r
source(file.path("R", "build_kanto_dashboard_data.R"))
build_kanto_dashboard_data()
```

If `data_clean/pref_population_2020.csv` exists, the builder also adds the Chapter 2 e-Stat population output and 2020 GDP per capita. If it does not exist, the app displays that the API result is unavailable.

## Run

```r
shiny::runApp(file.path("apps", "kanto_dashboard"))
```

## Data combined in the app

- Kanto administrative boundaries from MLIT National Land Numerical Information N03;
- station passenger counts from MLIT National Land Numerical Information S12;
- prefectural GDP, compensation of employees, and agriculture/forestry data used in Chapter 6;
- optional prefectural population created in Chapter 2.

Economic indicators cover 2011-2021. Population refers to 2020. Station passenger counts refer to 2024. Administrative boundaries refer to 2026-01-01. The app displays these reference years explicitly and does not treat them as a same-year causal comparison.
