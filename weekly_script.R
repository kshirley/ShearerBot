#2345678901234567890123456789012345678901234567890123456789012345678901234567890

# clear the workspace:
rm(list=ls())
gc()

# Set the working directory to the repo:
setwd("~/Stats/ShearerBot")

# set the week and some local directories to store output:
week <- "02"
ptp.out.dir <- "~/Stats/ptp/ptp-raw"
betfair.out.dir <- "~/Stats/ptp/betfair-raw"
betfair.id.input.file <- file.path("~/Stats/ptp/betfair-id", 
                                   paste0(week, ".txt"))
summary.file.path <- "~/Stats/ptp/summary"

# utility functions
su <- function(x) sort(unique(x))
lu <- function(x) length(unique(x))

# libraries:
suppressWarnings(library(RCurl, quietly=TRUE, warn.conflicts=FALSE, 
                 verbose=FALSE))
suppressWarnings(library(XML, quietly=TRUE, warn.conflicts=FALSE, 
                 verbose=FALSE))
library(knitr)

# source the get.table() function:
source("get_table.R")
source("download_betfair.R")

# read in the week from standard input:
#f <- file("stdin")
#open(f)
#week <- readLines(f, n=1)
#close(f)

# Get the table of outcomes from predictthepremiership.com:
if (week == "380") {  # custom vecor of ids when necessary
  id.vec <- c(321)
} else {
  id.vec <- (as.numeric(week) - 1)*10 + 1:10
}
n.games <- length(id.vec)
y <- as.list(rep(NA, n.games))
for (i in 1:n.games) {
  y[[i]] <- get.table(id.vec[i], out.dir = ptp.out.dir)
}

# set up list to gather betfair odds data:
betfair.id <- readLines(betfair.id.input.file)
lb <- length(betfair.id)
betfair <- as.list(rep(NA, lb))

# First try:
for (i in 1:lb) {
  print(i)
  betfair[[i]] <- download.betfair(betfair.id[i], week, 
                                   out.dir = betfair.out.dir)
}


# old code for trying a few times since the downloads were buggy sometimes
# last year:

# Second try:
#teams <- sapply(betfair, function(x) x$teams)
#w <- which(teams[1, ] == "none")

#if (length(w) > 0) {
  #print(w)
#  for (i in w) {
#    betfair[[i]] <- download.betfair(betfair.id[i], week)
#  }
  # Third and last try:
#  tms <- sapply(betfair, function(x) x$teams)
#  w2 <- which(tms[1, ] == "none")
#  if (length(w2) > 0) {
  	#print(w2)
#  	for (i in w2) {
#  	  betfair[[i]] <- download.betfair(betfair.id[i], week)
#  	}
#  }
#}  

# get a new list summarizing the strategy for this weeks' matches:
y.new <- as.list(rep(NA, n.games))

# Add some stuff to y:
# Wrap this in a function soon:
for (i in 1:n.games) {
  z <- y[[i]]
  team.match <- sapply(betfair, function(x) x$teams)[1, ] == z$teams[1]
  if (sum(team.match) == 1) {
    w <- which(team.match)
    n.outcomes <- dim(z$summary)[1]
    b.prob <- numeric(n.outcomes)
    betfair.p <- numeric(3)
    for (j in 1:length(b.prob)) {
  	  home.match <- betfair[[w]]$df[, 1] == z$summary[j, 1]
  	  away.match <- betfair[[w]]$df[, 2] == z$summary[j, 2]
  	  if (sum(home.match & away.match)  == 1) {
        b.prob[j] <- betfair[[w]]$df[home.match & away.match, 4]
      } else {
        b.prob[j] <- 0
      }
    }
    b.prob <- b.prob/sum(b.prob)
    type <- ifelse(z$summary[, 1] > z$summary[, 2], 1, 
                   ifelse(z$summary[, 1] == z$summary[, 2], 2, 3))
    betfair.p <- aggregate(b.prob, by=list(type), FUN=sum)
    betfair.p <- betfair.p[, 2]/sum(betfair.p[, 2]) # fix any rounding errors
    
    # loop through the outcomes and compute points from each possible outcome:
    score1 <- z$summary[, 1]
    score2 <- z$summary[, 2]
    p <- z$p
    probs <- z$summary$prob
  
    points <- matrix(0, n.outcomes, 5)
    # 0 points:
    # wrong result
    points[, 1] <- (score1 > score2)*(1 - betfair.p[1]) + 
                   (score1 == score2)*(1 - betfair.p[2]) + 
                   (score1 < score2)*(1 - betfair.p[3])

    # 1 point:
    # right result, wrong score, result probability greater than 20%
    points[, 2] <- (score1 > score2) * (betfair.p[1] - b.prob) * 
                   as.numeric(p[1] >= 0.2) + 
                   (score1 == score2) * (betfair.p[2] - b.prob) * 
                   as.numeric(p[2] >= 0.2) + 
                   (score1 < score2) * (betfair.p[3] - b.prob) * 
                   as.numeric(p[3] >= 0.2)

    # 3 points:
    # right result, wrong score, result less than 20%
    # + right result, right score, result > 20% and score > 5%:
    points[, 3] <- (score1 > score2) * (betfair.p[1] - b.prob) * 
                   as.numeric(p[1] < 0.2) + 
                   (score1 == score2) * (betfair.p[2] - b.prob) * 
                   as.numeric(p[2] < 0.2) + 
                   (score1 < score2) * (betfair.p[3] - b.prob) * 
                   as.numeric(p[3] < 0.2) + 
                   (score1 > score2) * b.prob * 
                   as.numeric(p[1] >= 0.2)*as.numeric(probs >= 0.05) + 
                   (score1 == score2) * b.prob * 
                   as.numeric(p[2] >= 0.2)*as.numeric(probs >= 0.05) + 
                   (score1 < score2) * b.prob * 
                   as.numeric(p[3] >= 0.2)*as.numeric(probs >= 0.05)

    # 5 points:
    # right result, right score, result >= 20%, score < 5%  OR 
    # right result, right score, result < 20%, score >= 5%:
    points[, 4] <- (score1 > score2) * (b.prob) * 
                   as.numeric(p[1] >= 0.2)*as.numeric(probs < 0.05) + 
                   (score1 == score2) * (b.prob) * 
                   as.numeric(p[2] >= 0.2)*as.numeric(probs < 0.05) + 
                   (score1 < score2) * (b.prob) * 
                   as.numeric(p[3] >= 0.2)*as.numeric(probs < 0.05) + 
                   (score1 > score2) * (b.prob) * 
                   as.numeric(p[1] < 0.2)*as.numeric(probs >= 0.05) + 
                   (score1 == score2) * (b.prob) * 
                   as.numeric(p[2] < 0.2)*as.numeric(probs >= 0.05) + 
                   (score1 < score2) * (b.prob) * 
                   as.numeric(p[3] < 0.2)*as.numeric(probs >= 0.05)

    # 7 points:
    # right result, right score, result < 20%, score < 5%:
    points[, 5] <- (score1 > score2) * (b.prob) * 
                   as.numeric(p[1] < 0.2)*as.numeric(probs < 0.05) + 
                   (score1 == score2) * (b.prob) * 
                   as.numeric(p[2] < 0.2)*as.numeric(probs < 0.05) + 
                   (score1 < score2) * (b.prob) * 
                   as.numeric(p[3] < 0.2)*as.numeric(probs < 0.05)

    # compute expected number of points:
    b.expected.points <- apply(t(t(points)*c(0, 1, 3, 5, 7)), 1, sum)
    b.expected.points.squared <- apply(t(t(points)*c(0, 1, 3, 5, 7)^2), 1, sum)
    b.var.points <- b.expected.points.squared - b.expected.points^2

    new.summary <- data.frame(z$summary, 
                              b.prob = b.prob, 
                              b.expected = b.expected.points, 
                              b.sd = sqrt(b.var.points))
    names(new.summary)[3:6] <- c("% picked", "Probability", "Expected", "SD")
    y.new[[i]] <- list(n = z$n, 
                       teams = z$teams, 
                       p = z$p, 
                       betfair.p = betfair.p, 
                       summary = new.summary)
  } else {
  	y.new[[i]] <- list(n = 0, 
  	                   teams = z$teams, 
  	                   p = NULL, 
  	                   betfair.p = NULL, 
  	                   summary = NULL)
  }
}


# save the y.new object:
summary.file <- paste0("summary-", week, "-", 
                       gsub(" ", "-", as.character(Sys.time())), ".RData")
save(y.new, file = file.path(summary.file.path, summary.file))

# function to extract highest expected points for each game:
get.max <- function(x) {
  tmp <- x$summary[which.max(x$summary[, "Expected"]), ]  
  df <- data.frame(Team1 = gsub(".", " ", names(tmp)[1], fixed = T), 
                   Team2 = gsub(".", " ", names(tmp)[2], fixed = T), 
                   tmp, 
                   n = x$n, stringsAsFactors = FALSE)
  names(df)[3:4] <- c("Score1", "Score2")
  for (i in 6:8) df[, i] <- round(df[, i], 3)
  names(df)[5] <- "% Picked"
  df
}

# gather the best pick for each game:
output.table <- do.call(rbind, lapply(y.new, get.max))
rownames(output.table) <- 1:n.games
output.table
# Go to the web and input these predictions


prediction.summary <- data.frame(Week = rep(week, n.games), 
                                 Time = rep(Sys.time(), n.games), 
                                 output.table, stringsAsFactors = FALSE)
names(prediction.summary)[7] <- "% Picked"
kb <- kable(prediction.summary)

# Cat the results to the README:
cat("# ShearerBot", file = "README.md")
cat("\n", file = "README.md", append = TRUE)
cat("A program to make my predictions for \"Predict the Premiership\"", 
    file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("Latest Predictions:", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("<sub>", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat(capture.output(print(kb)), sep = "\n", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("</sub>", file = "README.md", append = TRUE)



# Old stuff to print out plain text summary
# Keep here for now in case we want to do this again:
if (FALSE) {
total.expected <- 0
total.var <- 0
te <- 0
tv <- 0
for (i in 1:n.games) {
  if (y.new[[i]]$n > 0) {
    # penalized max expected (using 0.3 seems to choose safer bets, 
    # only giving up a bit of expected points)
    o <- order(y.new[[i]]$summary[, "Expected"] - 
               0.3*y.new[[i]]$summary[, "SD"], decreasing = TRUE)  	
    w2 <- o[1]
    # the old way, just maximizing expected points:
    w <- which.max(y.new[[i]]$summary[, "Expected"])
    total.expected <- total.expected + y.new[[i]]$summary[w, "Expected"]
    total.var <- total.var + y.new[[i]]$summary[w, "SD"]^2
    te <- te + y.new[[i]]$summary[w2, "Expected"]
    tv <- tv + y.new[[i]]$summary[w2, "SD"]^2
    cat("--------------------------------------------\n")
    cat("Game ", i, ": (n = ", y.new[[i]]$n, ")\n", sep="")
    cat(y.new[[i]]$teams[1], " ", sep="")
    cat(y.new[[i]]$summary[w, 1], " - ", y.new[[i]]$summary[w, 2], " ", sep="")
    cat(y.new[[i]]$teams[2], "\n", sep="")
    m <- max(nchar(y.new[[i]]$teams)) - nchar(y.new[[i]]$teams)
    cat(rep(" ", m[1]), 
        y.new[[i]]$teams[1], 
        " win: ", 
        sprintf("%04.1f", round(y.new[[i]]$betfair.p[1], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(y.new[[i]]$p[1], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat(rep(" ", 
        max(nchar(y.new[[i]]$teams)) - 0), 
        "Draw: ", 
        sprintf("%04.1f", round(y.new[[i]]$betfair.p[2], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(y.new[[i]]$p[2], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat(rep(" ", 
        m[2]), 
        y.new[[i]]$teams[2], 
        " win: ", 
        sprintf("%04.1f", round(y.new[[i]]$betfair.p[3], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(y.new[[i]]$p[3], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat("P(", 
        y.new[[i]]$summary[w, 1], 
        " - ", 
        y.new[[i]]$summary[w, 2], 
        ") = ", 
        round(y.new[[i]]$summary[w, "Probability"], 3)*100, 
        "%, picked by ", 
        y.new[[i]]$summary[w, 3]*100, 
        "% in pool\n", 
        sep="")
    cat("E(points) = ", 
        round(y.new[[i]]$summary[w, 5], 2), 
        ", sd(points) = ", 
        round(y.new[[i]]$summary[w, 6], 2), 
        "\n\n", 
        sep="")
  }
}
cat("\nE(total) = ", round(total.expected, 2), " SD(total) = ", round(sqrt(total.var), 2), "\n")
cat("\n  E(old) = ", round(te, 2), "   SD(old) = ", round(sqrt(tv), 2), "\n")
cat("\n\nhttp://www.predictthepremiership.com/?lang=en_us\n\n")
}

