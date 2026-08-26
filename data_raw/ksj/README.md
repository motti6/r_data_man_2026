# KSJ data for Chapters 7 and 8

Do not rename the extracted spatial files. Keep all technical path names ASCII-only.

## 1. Administrative boundary (N03)

- Page: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html
- Select: Kanto region, 2026
- Expected ZIP name: `N03-20260101_53_GML.zip`
- Extract into: `data_raw/ksj/n03_kanto/`

The course uses these shapefile fields:

- `N03_001`: prefecture name
- `N03_004`: municipality name
- `N03_007`: local government code

## 2. Station passenger count (S12)

- Page: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-S12-2024.html
- Select: nationwide, 2024
- Expected ZIP name: `S12-25_GML.zip`
- Extract into: `data_raw/ksj/s12_station/`

The course uses these shapefile fields:

- `S12_001`: station name
- `S12_001g`: station group code
- `S12_002`: operator
- `S12_003`: line name
- `S12_059`: availability status for 2024
- `S12_061`: passengers per day for 2024

## Attribution

When publishing output, cite the data and describe any processing. A suitable course-level note is:

> Source: MLIT, National Land Numerical Information (Administrative Boundary N03; Station Passenger Count S12). Boundaries were dissolved and simplified; station line features were aggregated to representative points.

Always confirm the license and notes shown on the page for the exact version used.
