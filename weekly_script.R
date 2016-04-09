#2345678901234567890123456789012345678901234567890123456789012345678901234567890

# clear the workspace:
rm(list=ls())
gc()

# Set the working directory to the repo:
setwd("~/Stats/ShearerBot")

# set the week and some local directories to store output:
week <- "33"
ptp.out.dir <- "~/Stats/ptp/ptp-raw"
betfair.out.dir <- "~/Stats/ptp/betfair-raw"
betfair.id.input.file <- file.path("~/Stats/ptp/betfair-id", 
                                   paste0(week, ".txt"))
summary.file.path <- "~/Stats/ptp/summary"

# utility functions
su <- function(x) sort(unique(x))
lu <- function(x) length(unique(x))

# load libraries:
library(knitr)
library(RCurl)
library(XML)

# source the main functions:
source("get_table.R")
source("download_betfair.R")
source("make_pick.R")

# set the vector of game ID numbers from predictthepremiership.com:
#id.vec <- (as.numeric(week) - 1)*10 + 1:10
id.vec <- c(321:330)
n.games <- length(id.vec)

# download the table of aggregated predictions:
ptp.table <- as.list(rep(NA, n.games))
for (i in 1:n.games) {
  ptp.table[[i]] <- get.table(id.vec[i], out.dir = ptp.out.dir)
}

# set up list to gather betfair odds data:
betfair.id <- readLines(betfair.id.input.file)
n.betfair <- length(betfair.id)

# check to see if the number of games matches:
if (n.games != n.betfair) {
  print("Error: Number of games to predict doesn't match number of betfair IDs")
}

# Download the betfair odds:
betfair <- as.list(rep(NA, n.betfair))
for (i in 8:n.betfair) {
  print(i)
  betfair[[i]] <- download.betfair(betfair.id[i], week, 
                                   out.dir = betfair.out.dir)
}

sapply(betfair, function(x) x$teams)

# Get E(points) and sd(points) for every score, every game:
points.table <- make.pick(ptp.table = ptp.table, betfair = betfair)

# save the points.table object:
summary.file <- paste0("summary-", week, "-", 
                       gsub(" ", "-", as.character(Sys.time())), ".RData")
save(points.table, file = file.path(summary.file.path, summary.file))

# function to extract the score yielding the highest expected points 
# for each game:
get.max <- function(x) {
  if (!is.null(x$summary)) {
    tmp <- x$summary[which.max(x$summary[, "Expected"]), ]  
    df <- data.frame(Home = gsub(".", " ", names(tmp)[1], fixed = T), 
                     Away = gsub(".", " ", names(tmp)[2], fixed = T), 
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
  df
}

# gather the best pick for each game:
output.table <- do.call(rbind, lapply(points.table, get.max))
rownames(output.table) <- 1:n.games
output.table

# set up the table for the README:
total.var <- round(sqrt(sum(output.table[, "SD"]^2, na.rm = TRUE)), 2)
x <- rbind(output.table, c("Total", "", "-", "-", "-", "-", 
                         sum(output.table[, "Expected"], na.rm = TRUE), 
                         total.var, 
                         max(output.table[, "n"], na.rm = TRUE)))

# Format for markdown:
kb <- kable(x)

# To do: for sunday updates, only replace the predictions for sunday games.

#r <- readLines("README.md")
#na <- is.na(output.table[, 3])
#kb[3:12][na] <- r[16:25][na]
#as.numeric(sapply(strsplit(r[16:25], "|", fixed = TRUE), function(x) x[8]))


# Cat the results to the README:
cat("# ShearerBot\n", file = "README.md")
cat("A program to make my predictions for \"Predict the Premiership\"", 
    file = "README.md", append = TRUE)
cat("\n\n", file = "README.md", append = TRUE)
cat("On the web: http://www.predictthepremiership.com/profile/index/30978", 
    file = "README.md", append = TRUE)
cat("\n\n", file = "README.md", append = TRUE)
cat("Latest Predictions:\n\n", file = "README.md", append = TRUE)
cat(paste0("Week = ", as.numeric(week), "\n\n"), file = 
             "README.md", append =TRUE)
cat(as.character(Sys.time()), file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("<sub>", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat(capture.output(print(kb)), sep = "\n", file = "README.md", append = TRUE)
cat("\n", file = "README.md", append = TRUE)
cat("</sub>", file = "README.md", append = TRUE)


# Append the writeup:
writeup <- readLines("shearer.md")
cat("\n\n", writeup, "\n", sep = "\n", file = "README.md", append = TRUE)

# Add, commit, and push the README.md file to the repo.
# Enter the picks manually online














# Old stuff to print out plain text summary
# Keep here for now in case we want to do this again:
if (FALSE) {
total.expected <- 0
total.var <- 0
te <- 0
tv <- 0
for (i in 1:n.games) {
  if (points.table[[i]]$n > 0) {
    # penalized max expected (using 0.3 seems to choose safer bets, 
    # only giving up a bit of expected points)
    o <- order(points.table[[i]]$summary[, "Expected"] - 
               0.3*points.table[[i]]$summary[, "SD"], decreasing = TRUE)  	
    w2 <- o[1]
    # the old way, just maximizing expected points:
    w <- which.max(points.table[[i]]$summary[, "Expected"])
    total.expected <- total.expected + points.table[[i]]$summary[w, "Expected"]
    total.var <- total.var + points.table[[i]]$summary[w, "SD"]^2
    te <- te + points.table[[i]]$summary[w2, "Expected"]
    tv <- tv + points.table[[i]]$summary[w2, "SD"]^2
    cat("--------------------------------------------\n")
    cat("Game ", i, ": (n = ", points.table[[i]]$n, ")\n", sep="")
    cat(points.table[[i]]$teams[1], " ", sep="")
    cat(points.table[[i]]$summary[w, 1], " - ", points.table[[i]]$summary[w, 2], " ", sep="")
    cat(points.table[[i]]$teams[2], "\n", sep="")
    m <- max(nchar(points.table[[i]]$teams)) - nchar(points.table[[i]]$teams)
    cat(rep(" ", m[1]), 
        points.table[[i]]$teams[1], 
        " win: ", 
        sprintf("%04.1f", round(points.table[[i]]$betfair.p[1], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(points.table[[i]]$p[1], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat(rep(" ", 
        max(nchar(points.table[[i]]$teams)) - 0), 
        "Draw: ", 
        sprintf("%04.1f", round(points.table[[i]]$betfair.p[2], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(points.table[[i]]$p[2], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat(rep(" ", 
        m[2]), 
        points.table[[i]]$teams[2], 
        " win: ", 
        sprintf("%04.1f", round(points.table[[i]]$betfair.p[3], 3)*100), 
        "% (betfair), ",
        sprintf("%04.1f", round(points.table[[i]]$p[3], 3)*100), 
        "% (pool)\n", 
        sep="")
    cat("P(", 
        points.table[[i]]$summary[w, 1], 
        " - ", 
        points.table[[i]]$summary[w, 2], 
        ") = ", 
        round(points.table[[i]]$summary[w, "Probability"], 3)*100, 
        "%, picked by ", 
        points.table[[i]]$summary[w, 3]*100, 
        "% in pool\n", 
        sep="")
    cat("E(points) = ", 
        round(points.table[[i]]$summary[w, 5], 2), 
        ", sd(points) = ", 
        round(points.table[[i]]$summary[w, 6], 2), 
        "\n\n", 
        sep="")
  }
}
cat("\nE(total) = ", round(total.expected, 2), " SD(total) = ", round(sqrt(total.var), 2), "\n")
cat("\n  E(old) = ", round(te, 2), "   SD(old) = ", round(sqrt(tv), 2), "\n")
cat("\n\nhttp://www.predictthepremiership.com/?lang=en_us\n\n")
}

