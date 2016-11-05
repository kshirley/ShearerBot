# function to extract the score yielding the highest expected points 
# for each game:
get.max <- function(x) {
  if (!is.null(x$summary)) {
    if (sum(is.na(x$summary$Expected)) != length(x$summary$Expected)) {
      tmp <- x$summary[which.max(x$summary[, "Expected"]), ]  
      df <- data.frame(Home = gsub(".", " ", names(tmp)[1], fixed = TRUE), 
                       Away = gsub(".", " ", names(tmp)[2], fixed = TRUE), 
                       tmp, 
                       n = x$n, stringsAsFactors = FALSE)
      names(df)[3:4] <- c("H", "A")
      for (i in 6:8) df[, i] <- round(df[, i], 3)
      names(df)[5] <- "% Picked"
      names(df)[6] <- "Prob"
    } else {
      df <- data.frame(Home = x$teams[1], Away = x$teams[2], 
                       H = NA, A = NA, picked = NA, 
                       Prob = NA, Expected = NA, SD = NA, n = NA, 
                       stringsAsFactors = FALSE)
      names(df)[5] <- "% Picked"
    } 
  } else {
    df <- data.frame(Home = x$teams[1], Away = x$teams[2], 
                     H = NA, A = NA, picked = NA, 
                     Prob = NA, Expected = NA, SD = NA, n = NA, 
                     stringsAsFactors = FALSE)
    names(df)[5] <- "% Picked"
  }
  df
}

