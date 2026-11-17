library(dplyr)
library(readr)
library(stringr)
library(tidyr)

sources <- tibble::tribble(
  ~league, ~repository, ~commit, ~path,
  "Premier League", "openfootball/england", "9ee7a0c351805c99cc334478a9bf04b7d0432fec", "{season}/1-premierleague.txt",
  "Bundesliga", "openfootball/deutschland", "c34532ab6950aa0089ef1c736ffdb8c818c3356f", "{season}/1-bundesliga.txt",
  "Serie A", "openfootball/italy", "48954d163c312aa705efacb64f771267031fe6eb", "{season}/1-seriea.txt",
  "La Liga", "openfootball/espana", "80035a93dd4920985af52aa097a54a6fb888563b", "{season}/1-liga.txt",
  "Ligue 1", "openfootball/europe", "63df627f3c87ce71708f016522ea236cf74332c3", "france/{season}_fr1.txt"
)

season_labels <- function(start_year) {
  paste0(start_year, "-", sprintf("%02d", (start_year + 1L) %% 100L))
}

read_match_file <- function(source, season_start) {
  season <- season_labels(season_start)
  path <- str_replace(source$path[[1]], fixed("{season}"), season)
  file_url <- paste0(
    "https://raw.githubusercontent.com/",
    source$repository[[1]], "/", source$commit[[1]], "/", path
  )
  lines <- readLines(file_url, warn = FALSE, encoding = "UTF-8")
  post_score <- str_match(
    lines,
    "^\\s*(?:\\d{1,2}:\\d{2}\\s+)?(.+?)\\s+(\\d+)\\s*-\\s*(\\d+)(?:\\s*\\([^)]*\\))?\\s+(.+?)\\s*$"
  )
  pre_score <- str_match(
    lines,
    "^\\s*(?:\\d{1,2}:\\d{2}\\s+)?(.+?)\\s+v\\s+(.+?)\\s+(\\d+)\\s*-\\s*(\\d+)(?:\\s*\\([^)]*\\))?\\s*$"
  )
  parsed <- tibble(
    home_team = str_trim(coalesce(post_score[, 2], pre_score[, 2])),
    home_goals = suppressWarnings(as.integer(coalesce(post_score[, 3], pre_score[, 4]))),
    away_goals = suppressWarnings(as.integer(coalesce(post_score[, 4], pre_score[, 5]))),
    away_team = str_trim(coalesce(post_score[, 5], pre_score[, 3]))
  ) %>%
    filter(
      !is.na(home_team),
      !is.na(away_team),
      !is.na(home_goals),
      !is.na(away_goals)
    )
  if (nrow(parsed) == 0) {
    stop("No completed matches parsed from ", file_url, call. = FALSE)
  }
  parsed %>%
    mutate(
      league = source$league[[1]],
      season_start = as.integer(season_start),
      source_repository = source$repository[[1]],
      source_commit = source$commit[[1]]
    )
}

requests <- tidyr::crossing(
  source_index = seq_len(nrow(sources)),
  season_start = 2014:2023
)
match_data <- purrr::map2_dfr(
  requests$source_index,
  requests$season_start,
  \(source_index, season_start) {
    read_match_file(sources[source_index, ], season_start)
  }
)

home_results <- match_data %>%
  transmute(
    league, season_start, team_name = home_team, goals_for = home_goals,
    goals_against = away_goals,
    points = case_when(
      home_goals > away_goals ~ 3,
      home_goals == away_goals ~ 1,
      TRUE ~ 0
    )
  )
away_results <- match_data %>%
  transmute(
    league, season_start, team_name = away_team, goals_for = away_goals,
    goals_against = home_goals,
    points = case_when(
      away_goals > home_goals ~ 3,
      away_goals == home_goals ~ 1,
      TRUE ~ 0
    )
  )

team_performance <- bind_rows(home_results, away_results) %>%
  group_by(league, season_start, team_name) %>%
  summarize(
    matches_played = n(),
    points = sum(points),
    goals_for = sum(goals_for),
    goals_against = sum(goals_against),
    goal_difference = goals_for - goals_against,
    points_per_game = points / matches_played,
    goal_difference_per_game = goal_difference / matches_played,
    .groups = "drop"
  ) %>%
  group_by(league, season_start) %>%
  arrange(desc(points), desc(goal_difference), desc(goals_for), team_name, .by_group = TRUE) %>%
  mutate(table_position = row_number()) %>%
  ungroup() %>%
  left_join(
    match_data %>%
      distinct(league, season_start, source_repository, source_commit),
    by = c("league", "season_start")
  ) %>%
  arrange(league, season_start, table_position)

league_coverage <- team_performance %>%
  group_by(league, season_start) %>%
  summarize(
    teams = n(),
    min_matches_per_team = min(matches_played),
    max_matches_per_team = max(matches_played),
    .groups = "drop"
  )
bad_coverage <- league_coverage %>%
  filter(min_matches_per_team < 25L | max_matches_per_team > 38L)
if (nrow(bad_coverage) > 0) {
  stop(
    "Unexpected match coverage:\n",
    paste(capture.output(print(bad_coverage)), collapse = "\n"),
    call. = FALSE
  )
}

dir.create("data", showWarnings = FALSE)
write_csv(team_performance, "data/team_season_performance.csv")
message(
  "Wrote ", nrow(team_performance), " team-season rows covering ",
  nrow(league_coverage), " league seasons."
)
