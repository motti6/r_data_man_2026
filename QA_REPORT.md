# QA report

## Naming convention

- All distributed file and folder names are ASCII only.
- Excel sheet names and column headers used by the course are ASCII only.
- CSV headers are ASCII only and CSV files are UTF-8.
- R identifiers in executable QMD code contain no Japanese characters.
- Japanese is retained only where it is data or presentation text, such as prefecture names, survey comments, API labels, captions, and explanations.

## Normalized data files

- `analysis_data.xlsx`: `trade_query`, `trade`, `tx_data`, `pharma_finance`, `pharma_patent`, `bop`, `watcher_text`
- `a_bop.csv`: `year`, `month`, `current_account`, `goods_services_balance`, `trade_balance`, `exports`, `imports`, `services_balance`, `primary_income`, `secondary_income`
- `a_usdjpy.csv`: `year`, `month`, `usd_jpy`
- `b_weo.xlsx`: `weo`, `group_map`; key fields include `iso`, `subject_code`, `country`, `units`, `scale`, `estimates_start_after`
- `c_pref_gdp.xlsx`: `gdp`, `compensation`, `agri_forestry`; the last sheet uses `agriculture` and `forestry`

## Static checks

- QMD R code fences are paired.
- Basic bracket/parenthesis balance checks passed for all R chunks.
- Quarto chunk labels are unique.
- File and sheet references in QMD use ASCII names.
- The updated exercise DOCX was rendered and visually checked on all three pages.

## Data cross-checks

- `a_bop.csv`: 351 rows, 1996-01 through 2025-03.
- Minimum calculated `trade_balance`: -20330 in 2022-10.
- WEO 2023 PPPGDP group totals reproduce the prior checks: G7 54338.781, EU 13553.258, ASEAN 11469.904.

## Environment limitation

This environment does not have R or the Quarto CLI, so a full R execution and HTML render could not be performed here. Run `source("setup_packages.R")` and then `quarto preview` in Positron for the final machine-specific check.

## Chapters 7 and 8 additions

- Added `chapter7_2026.qmd` and `chapter8_2026.qmd`.
- Added ASCII-only KSJ directories and download instructions.
- Added spatial helper and reproducible bundle builder scripts.
- Added starter and completed Shiny apps.
- Added optional integration with Chapter 2 population output.
- Added the two chapters to `_quarto.yml` and `index.qmd`.
- Added `sf`, `units`, `leaflet`, `shiny`, `bslib`, and `DT` to package setup.

## Spatial/Shiny static checks completed

- YAML and Pandoc parsing passed for all nine QMD files (`index` and Chapters 1-8).
- R code fences are paired and all chunk labels are unique across the project.
- Basic R string, parenthesis, bracket, and brace checks passed for QMD chunks, helper scripts, setup, and both apps.
- UI output IDs and `server` output IDs match in the completed Shiny app.
- No distributed file/folder path or executable R identifier contains non-ASCII characters.
- Required N03/S12 field names are asserted before processing.
- N03 geometry is transformed before area and simplification operations.
- Full prefecture area and cropped display geometry are kept conceptually separate.
- Attribute joins declare their expected relationship.
- Spatial join input/output counts are exposed in Chapter 7.
- Shiny reads the RDS outside `server` and uses `leafletProxy()` for updates.
- Population output is optional and is not replaced with zero when absent.
- All technical file names, R identifiers, and chunk labels are ASCII-only.

A full R execution still requires the current N03 and S12 files to be downloaded and extracted. This container has Pandoc but not R or Quarto, so package installation, spatial processing, HTML rendering, and live Shiny interaction must receive one final machine-specific check in Positron.

