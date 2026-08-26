# Rデータ操作入門（2026年度・実データ版）

大学講義用のQuarto教材です。分析例は、配布された実データのスナップショットを使います。第2章ではe-Stat APIによる検索、メタデータ確認、取得、整形、保存までを扱い、以後の分析で「公表元から取得した原データ」と「分析用に整形したデータ」を分けて管理する習慣を身につけます。

## ファイル構成

- `chapter1_2026.qmd`: R、Quarto、プロジェクト、型、欠損値、実データの初読
- `chapter2_2026.qmd`: CSV/Excel、文字コード、e-Stat API、データ来歴
- `chapter3_2026.qmd`: dplyr、tidyr、国際収支、WEO、製薬データの結合
- `chapter4_2026.qmd`: 文字列、日付、反復処理、景気コメント、都道府県GDP
- `chapter5_2026.qmd`: ggplot2による実データ可視化
- `chapter6_2026.qmd`: 追加演習A～Cと折り畳み式の解答例
- `chapter7_2026.qmd`: 国土数値情報、sf、CRS、属性結合・空間結合
- `chapter8_2026.qmd`: Shiny、Leaflet、bslibによる地域ダッシュボード
- `R/estat_helpers.R`: e-Stat API 3.0用の講義用ヘルパー
- `R/spatial_helpers.R`: 地理データ読込・都道府県パネル用ヘルパー
- `R/build_kanto_dashboard_data.R`: 第7章から第8章へ渡すRDS/GeoPackageの生成
- `apps/kanto_dashboard_starter/`: 第8章の開始版
- `apps/kanto_dashboard/`: 第8章の完成例
- `data_raw/`: 配布時点の原データ。上書きしない（`data_raw/README.md`に一覧）
- `data_clean/`: API取得後または整形後のデータ
- `output_data/`, `figures/`: 表・図の出力先

## 命名規則

講義コードで参照するファイル名、フォルダ名、Excelシート名、Rオブジェクト名、列名は **ASCIIの英数字とアンダースコア** に統一しています。列名は原則として `snake_case` を使います。都道府県名や景気コメントなど、観測値そのものの日本語は保持します。

## 初回セットアップ

PositronまたはR Consoleで、プロジェクト直下から次を実行します。

```r
source("setup_packages.R")
```

`renv`を使っている場合は、不足パッケージがプロジェクト専用ライブラリへ入り、`renv.lock`が更新されます。前回のエラーで不足していた `knitr`、`rmarkdown`、`yaml` も対象です。

## e-Stat APIの準備

1. e-Statでユーザー登録し、アプリケーションIDを取得します。
2. `.Renviron.example` を `.Renviron` にコピーします。
3. `your_application_id_here` を自分のIDに置き換えます。
4. Rセッションを再起動します。
5. `nzchar(Sys.getenv("ESTAT_APP_ID"))` が `TRUE` になることを確認します。

APIを呼ぶコードは、通常のプレビューでは実行しない設定です。第2章では人口推計（統計表表示ID `0003448237`）を取得し、第5章の一人当たり都道府県GDPへ受け渡します。実行する場合は次のいずれかを使います。

```powershell
quarto render chapter2_2026.qmd -P run_api:true
```

または、該当コードをR Consoleで一つずつ実行します。授業では後者を推奨します。


## 第7章・第8章の準備

国土数値情報から次をダウンロードし、ZIPを展開します。

1. 行政区域N03、2026年、関東地方：`N03-20260101_53_GML.zip`
2. 駅別乗降客数S12、2024年、全国：`S12-25_GML.zip`

配置先は次のとおりです。

```text
data_raw/ksj/n03_kanto/
data_raw/ksj/s12_station/
```

詳細は`data_raw/ksj/README.md`と`chapter7_2026.qmd`を参照してください。第7章の処理後、次を作成します。

```r
source(file.path("R", "build_kanto_dashboard_data.R"))
build_kanto_dashboard_data()
```

完成アプリは次で起動します。

```r
shiny::runApp(file.path("apps", "kanto_dashboard"))
```

第2章で`data_clean/pref_population_2020.csv`を作成している場合は、2020年人口と一人当たりGDPもアプリへ追加されます。未作成でもアプリは停止せず、未取得であることを表示します。

## 推奨運用

- 講義中の再現性を確保するため、基本演習は `data_raw/` のスナップショットで行う。
- 第2章以降、更新可能な政府統計はAPIで再取得し、APIレスポンスのRDSと整形済みCSV/RDSを別々に保存する。
- WEOなどe-Stat外の統計は、公表元に応じた取得方法を使う。APIは万能な一つの入口ではなく、データ提供元との契約である。
- 元データは変更せず、加工コードを残して `data_clean/` を再生成できる状態にする。

## データの注意点

- `a_bop.csv` はUTF-8、`a_usdjpy.csv` はUTF-8で読み込みます。
- `b_weo.xlsx` はIMF WEO April 2025のスナップショットです。実績・予測の境界は国・系列で異なるため、`estimates_start_after`を確認してください。2030年は予測値です。
- `c_pref_gdp.xlsx` は令和3年度県民経済計算のスナップショットです。
- `analysis_data.xlsx` のTX・製薬・景気コメントは、変数定義や単位を授業配布時に確認してから解釈してください。
- N03は2026年1月1日時点、S12は2024年度、県民経済計算は2011～2021年です。Shiny画面では基準年の違いを明示します。
- S12の乗降客数は事業者ごとの資料に基づき、算出基準が全事業者で統一されているわけではありません。

## 参考

- e-Stat API利用ガイド: https://www.e-stat.go.jp/api/api-info/api-guide
- e-Stat API 3.0仕様: https://www.e-stat.go.jp/api/api-info/e-stat-manual3-0
- 国土数値情報: https://nlftp.mlit.go.jp/ksj/
- sf: https://r-spatial.github.io/sf/
- Shiny: https://shiny.posit.co/r/getstarted/
- Leaflet for R: https://rstudio.github.io/leaflet/
- bslib dashboards: https://rstudio.github.io/bslib/articles/dashboards/index.html
