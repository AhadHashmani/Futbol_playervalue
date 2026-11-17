# Football Player Market Value Prediction

Estimating football player market values from on-field performance, then examining where observed valuations differ from model expectations. The project combines FBref statistics with Transfermarkt valuations and compares four regression approaches to support data-informed scouting and recruitment analysis.

**[Read the historical research report](football_player_market_value_report.pdf)** · **[Explore the current modeling analysis](player_market_value_analysis.Rmd)**

The PDF contains results from an earlier random-split analysis. The current R Markdown workflow uses time-ordered evaluation and writes fresh metrics when rendered; the historical PDF should not be used as evidence for the revised model.

## Current approach

1. **Prepare and match records.** Normalize Unicode player names, use birth year to disambiguate names, standardize league names, aggregate a player's same-season club stints, and exclude ambiguous source identities. A source-matching summary is rendered and saved.
2. **Handle missing features.** Numeric imputations are learned from training seasons only, with missingness indicators retained.
3. **Evaluate over time.** Train on earlier seasons, select a model and calibrate prediction intervals on the penultimate season, then evaluate once on the latest season. Report RMSE, MAE, conventional R-squared, and nominal 90% interval coverage.
4. **Interpret model gaps carefully.** Player-level outputs compare reported values with model estimates. They describe gaps, not proven market mispricing.

The source snapshots do not include valuation timestamps. The time-ordered test therefore measures performance on a later season, but does not guarantee a prospective forecast using only information available at valuation time.

## Data and files

The included snapshots contain **30,505 FBref rows** and **40,520 Transfermarkt rows** before filtering and joining. FBref covers the five major European leagues with season-end years 2014–2024. Transfermarkt uses season-start years 2014–2024 and also includes some lower-division records; the modeling join determines the final sample.

| File | Purpose |
| --- | --- |
| [football_player_market_value_report.pdf](football_player_market_value_report.pdf) | Research narrative, model comparison, visualizations, and interpretation |
| [player_market_value_analysis.Rmd](player_market_value_analysis.Rmd) | Feature engineering, model training, evaluation, and residual analysis |
| [R/data_pipeline.R](R/data_pipeline.R) | Name/league normalization, ambiguity checks, and source matching |
| [R/model_metrics.R](R/model_metrics.R) | Regression metrics, log-to-euro correction, and prediction intervals |
| [app.R](app.R) | Shiny explorer for latest-season model gaps |
| [tests/run_checks.R](tests/run_checks.R) | Data-integrity and metric checks |
| [predicting_player_market_value.Rmd](predicting_player_market_value.Rmd) | Exploratory analysis and commented data-collection code |
| [all_leagues_stats.csv](all_leagues_stats.csv) | FBref performance snapshot |
| [market_values.csv](market_values.csv) | Transfermarkt valuation snapshot |

## Reproduce the analysis

Use **R and RStudio**, or R with Pandoc available. The CSV snapshots are included. Dependencies are managed with `renv`:

```bash
git clone https://github.com/anikethk1/player_market_value_prediction.git
cd player_market_value_prediction
```

From the repository root, restore the locked project library:

```bash
Rscript -e 'install.packages("renv", repos = "https://cloud.r-project.org")'
Rscript -e 'renv::restore(prompt = FALSE)'
```

After intentionally changing package dependencies, update the lockfile with `renv::snapshot()`.

Run the focused checks, then render the current analysis:

```bash
Rscript tests/run_checks.R
Rscript -e 'rmarkdown::render("player_market_value_analysis.Rmd", output_format = "html_document", knit_root_dir = getwd(), envir = new.env())'
```

The report writes:

- `player_market_value_analysis.html` — rendered report
- `model_comparison.csv` and `evaluation_summary.csv` — calibration/test performance and split details
- `player_valuations.csv` — latest-season predictions, 90% intervals, and model gaps
- `efficiency_by_position.csv`, `efficiency_by_league.csv`, and `data_quality_summary.csv` — summaries and matching diagnostics

Launch the interactive explorer after rendering:

```bash
Rscript -e 'shiny::runApp()'
```

GitHub Actions runs the data checks and renders the report on pushes and pull requests.

## Project team and sources

Aniketh Kalagara, Palash, Jovan, and Kelly, as credited in the analysis.

Data sources: [FBref](https://fbref.com/en/) and [Transfermarkt](https://www.transfermarkt.com/). The exploratory document includes the original collection approach using [worldfootballR](https://github.com/JaseZiv/worldfootballR).
