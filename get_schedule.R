get.schedule <- function() {
  splashurl <- "http://www.predictthepremiership.com/?lang=en_us"
  loginurl <- "https://premierleague.predictthefootball.com/site/login?lang=en_us"
  mainurl <- "https://premierleague.predictthefootball.com/profile/index"
  ua <-  "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322)"
  
  info <- readLines("~/ptp-kshirley.txt")
  email <- info[1]
  passwd <- info[2]

  curl <- getCurlHandle()
  curlSetOpt(cookiejar = "", useragent = ua, followlocation = TRUE, curl = curl)

  html <- getURL(splashurl, curl = curl)

  YII.CSRF.TOKEN <- str_extract( html , "\"[:xdigit:]{40}\"")
  YII.CSRF.TOKEN <- substring(YII.CSRF.TOKEN, 2, 41)

  pars <- list('YII_CSRF_TOKEN' = YII.CSRF.TOKEN, 
               'LoginForm[email]' = email, 
               'LoginForm[password]' = passwd, 
               'LoginForm[rememberMe]' = '0')

  html <- postForm(loginurl, .params = pars, curl = curl)

  h <- read_html(html)
  id <- html_nodes(h, ".statsBtn")
  id.vec <- as.integer(gsub("\"", "", substr(id, 92, 93)))
  return(id.vec)
}
