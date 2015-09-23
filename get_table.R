#1234567890123456789012345678901234567890123456789012345678901234567890123456789
get.table <- function(game.id, out.dir) {

  # read in the URL:
  domain <- "https://premierleague.predictthefootball.com/"
  path  <- paste0("site/stats?fixtureid=", game.id)
  data <- getURL(paste0(domain, path), ssl.verifypeer = FALSE)
  cat(data, file = file.path(out.dir, paste0("ptp", week, "-", 
      gsub(" ", "-", Sys.time()), "-", game.id)))
  data <- unlist(strsplit(data, "\n"))

  # scrape the sample size:
  n <- as.numeric(strsplit(data[grep("Total predictions", data)], 
                  "[[:space:]]+")[[1]][4])

  # scrape the two teams that are playing this match:
  teams <- strsplit(strsplit(strsplit(data[grep("modal-title", 
                    data)], ">")[[1]][2], "<")[[1]], " v ")[[1]]
  teams <- gsub("^+[[:space:]]", "", teams)
  teams <- gsub("[[:space:]]$+", "", teams)
  # home team is listed first

  # get the starting and ending lines of the table:
  table.start <- grep("table table-x-condensed table-hover", data)
  table.end <- grep("</table>", data)
  table.end <- table.end[table.end > table.start][1]

  # scrape the scores that have been predicted:
  n.outcomes <- ((table.end + 1) - (table.start + 2))/4
  score.lines <- data[table.start + seq(2, by=4, length=n.outcomes)]
  scores <- strsplit(gsub("</td", "", sapply(strsplit(score.lines, 
                     ">"), function(x) x[2])), "-")
  score1 <- sapply(scores, function(x) as.numeric(x[1]))
  score2 <- sapply(scores, function(x) as.numeric(x[2]))

  # scrape the probability of each outcome:
  prob.lines <- data[table.start + seq(3, by=4, length=n.outcomes)]
  probs <- as.numeric(gsub("%]</td>", "", sapply(strsplit(prob.lines, 
                      "\\["), function(x) x[2])))/100
  probs <- probs/sum(probs)

  # look at the possible outcomes in a data.frame:
  #data.frame(score1, score2, probs)

  # compute outcome probability vector:
  p <- numeric(3)
  p[1] <- sum(probs[score1 > score2])
  p[2] <- sum(probs[score1 == score2])
  p[3] <- sum(probs[score1 < score2])

  #summary <- data.frame(score1, score2, prob=round(probs, 3), 
  # expected=expected.points, sd=sqrt(var.points))
  summary <- data.frame(score1, score2, prob=round(probs, 3))
  names(summary)[1:2] <- teams

  return(list(n=n, teams=teams, p=p, summary=summary))
}

