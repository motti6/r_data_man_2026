# Chapters 7 and 8 teaching plan

## Intended audience

Students who completed Chapters 1-6 and can independently use `dplyr`, `tidyr`, joins, functions, `ggplot2`, and Quarto.

## Chapter 7: 90-minute plan

| Time | Topic | Instructor checkpoint |
|---|---|---|
| 0-10 min | Spatial questions and data model | Distinguish attribute join from spatial join |
| 10-20 min | KSJ download, metadata, license | Confirm exact versions and extracted files |
| 20-35 min | Read N03, inspect geometry and CRS | Ask why a displayed map is not enough |
| 35-50 min | Transform, dissolve, area, crop, simplify | Check `st_transform()` vs `st_set_crs()` |
| 50-65 min | Join Chapter 6 prefecture panel | Audit key uniqueness and row counts |
| 65-78 min | Read S12, aggregate station groups | Discuss max vs sum and missing values |
| 78-86 min | Spatial join and combined map | Compare input/output rows |
| 86-90 min | Build RDS and preview Chapter 8 | Confirm output files exist |

Suggested homework: Exercises 7-2 and 7-4.

## Chapter 8: 90-minute plan

| Time | Topic | Instructor checkpoint |
|---|---|---|
| 0-10 min | App architecture and reactive graph | Students identify input-output dependencies |
| 10-20 min | Run starter and inspect data bundle | Data is loaded outside `server` |
| 20-35 min | Sidebar and choropleth map | Metric, year, and legend update together |
| 35-50 min | Shared reactive data and KPI | No repeated joins across outputs |
| 50-65 min | Station layer and `leafletProxy()` | Empty filters do not crash the app |
| 65-75 min | Map click synchronization | Select input, map, and charts agree |
| 75-84 min | Trend, ranking, profile, sources | Reference years remain visible |
| 84-90 min | Extension pitch and review | Each student states one user question |

Suggested homework: add one new data layer and document the update pipeline.

## Before class

1. Run `source("setup_packages.R")`.
2. Confirm N03 and S12 are downloaded and extracted.
3. Run `build_kanto_dashboard_data()` once on the classroom machine.
4. Open both apps and test all inputs.
5. Keep the completed app hidden until students finish the staged exercises.

## Common failure modes

- Only the `.shp` file was copied.
- A ZIP was placed in the target folder without extraction.
- CRS was relabeled with `st_set_crs()` instead of transformed.
- Station values were summed without checking duplicated operators/lines.
- Tokyo's remote islands made the mainland map too small.
- A reactive expression reads Excel or shapefiles on every input change.
- UI IDs and `input`/`output` names differ by one character.
- Missing population data is treated as zero.
- Different reference years are shown without a note.
