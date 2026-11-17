source("app.R")

team_context_columns <- c(
  "team_name", "team_matches_played_prior", "team_points_per_game_prior",
  "team_goal_difference_per_game_prior", "team_table_position_prior"
)
stopifnot(
  all(team_context_columns %in% names(valuations)),
  any(!is.na(valuations$team_points_per_game_prior))
)

shiny::testServer(server, {
  session$setInputs(league = "All", position = "All", gap_status = "All")
  all_rows <- filtered_valuations()
  stopifnot(nrow(all_rows) > 0)
  stopifnot(all(team_context_columns %in% names(all_rows)))

  selected_league <- sort(unique(all_rows$league))[[1]]
  session$setInputs(league = selected_league)
  filtered_rows <- filtered_valuations()
  stopifnot(
    nrow(filtered_rows) > 0,
    all(filtered_rows$league == selected_league),
    nrow(filtered_rows) <= nrow(all_rows)
  )
})

message("Dashboard loaded and returned filtered player rows.")
