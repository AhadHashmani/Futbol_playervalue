source("app.R")

shiny::testServer(server, {
  session$setInputs(league = "All", position = "All", gap_status = "All")
  all_rows <- filtered_valuations()
  stopifnot(nrow(all_rows) > 0)

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
