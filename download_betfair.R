#1234567890123456789012345678901234567890123456789012345678901234567890123456789

### Download betfair data to get estimates of match outcome probabilities:
download.betfair <- function(game.id, week, out.dir) {

  # download the raw webpage from betfair:
  domain <- "https://www.betfair.com/"
  path <- paste0("sport/football/event?eventId=", game.id)

  betfair.raw <- ""
  iter <- 1
  while(length(gregexpr("\n", betfair.raw)[[1]]) < 6000 & iter < 4) {
  	print(paste0("Download Attempt #", iter))
    betfair.raw <- getURL(paste0(domain, path), ssl.verifypeer = FALSE)
    iter <- iter + 1
  }  

  # save it to a file:
  cat(betfair.raw, file = file.path(out.dir, 
      paste0("bf", week, "-", gsub(" ", "-", Sys.time()), "-", game.id)))

  # Parse it:
  if (length(grep("error-page error-page-plain", betfair.raw)) == 0) {
    z1 <- gregexpr("<span class=\"runner-name\">[0-9]{1,2} - [0-9]{1,2}</span>", 
                   betfair.raw)
    #z2 <- gregexpr("ui-fraction-price\"> [0-9]{1,4}/[0-9]{1,4} ", betfair.raw)
    z2 <- gregexpr("ui-[0-9]{1,}_[0-9]{1,}-[0-9]{1,} \"> [0-9.]{1,5} ", 
                   betfair.raw)
    match.length <- attr(z1[[1]], "match.length")
    match.length2 <- attr(z2[[1]], "match.length")
    l <- length(match.length)
    if (match.length[1] != -1) {
      full <- rep("", l)
      score <- matrix(0, l, 2)
      odds <- rep("", l)
      for (j in 1:l) {
  	    full[j] <- substr(betfair.raw, z1[[1]][j], z1[[1]][j] + 
  	                      match.length[j] - 1)
  	    full[j] <- gsub("<[^>]*>", "", full[j])
  	    score[j, ] <- as.numeric(strsplit(full[j], " - ")[[1]])
  	    index <- min(which(z2[[1]] > z1[[1]][j]))
        if (z2[[1]][index] - z1[[1]][j] > 900) {
          odds[j] <- "1/0"
        } else {
  	      tmp <- substr(betfair.raw, z2[[1]][index], z2[[1]][index] + 
  	                    match.length2[index] - 1)
  	      odds[j] <- gsub("ui-[0-9]{1,}_[0-9]{1,}-[0-9]{1,} \"> ", "", tmp)
  	    }
      }
      df <- data.frame(score, odds, stringsAsFactors=FALSE)
      df <- unique(df)
      df <- df[df[, 1] < 7 & df[, 2] < 7, ]
      #probs <- sapply(strsplit(df[, 3], "/", fixed=TRUE), 
      #                function(x) as.numeric(x[2])/sum(as.numeric(x)))
      probs <- 1/(as.numeric(df[, 3]) - 1)
      tmp <- strsplit(betfair.raw, "\n")[[1]]
      g <- grep("<h2 class=\"team-names\">", tmp)
      if (length(g) > 0) {
        teams <- unlist(strsplit(unlist(strsplit(tmp[g], "<")), ">"))[c(2, 5)]
        teams <- gsub("C Palace", "Crystal Palace", teams)      
        betfair <- list(teams=teams, 
                        df=data.frame(df, probs, stringsAsFactors=FALSE))
      } else {
        betfair <- list(teams=c("none", "none"), df=NULL)      
      }
    } else {
      betfair <- list(teams=c("none", "none"), df=NULL)
    }
  } else {
    betfair <- list(teams=c("none", "none"), df=NULL)
  }
  return(betfair)
}

