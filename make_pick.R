make.pick <- function(ptp.table, betfair) {

  # set up an object to hold all info for each game:
  n.games <- length(ptp.table)
  y.new <- as.list(rep(NA, n.games))

  # loop through each game:
  for (i in 1:n.games) {
    z <- ptp.table[[i]]
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
      b.prob[is.na(b.prob)] <- 0
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
  return(y.new)
}
