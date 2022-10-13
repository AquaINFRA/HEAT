
# load header function into top of search list
source("OxygenDebt/00_initialise.R")

# get scripts to run
files <- paste0("OxygenDebt/", dir("OxygenDebt/", pattern = "^(data|input|model|output)_.*[.]R$"))

# don't run download script if you already have the data
#files <- files[-1]

# run scripts in correct order
for (file in sort(files)) {
  source(file, echo = TRUE, keep.source = TRUE)
}

