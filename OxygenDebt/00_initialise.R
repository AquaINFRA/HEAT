# load header function into top of search list
while("tools:oxydebt_funs" %in% search()) detach("tools:oxydebt_funs")
sys.source("OxygenDebt/00_header.R", envir = attach(NULL, name = "tools:oxydebt_funs"))

# set some options
options(stringsAsFactors = FALSE)

