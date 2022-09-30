library("readxl")
library("data.table")

assessmentPeriod <- "2016-2021"

inputPath <- file.path("Input", assessmentPeriod)

dir.create(inputPath, showWarnings = FALSE, recursive = TRUE)

url <- "https://www.dropbox.com/s/d9zd3ki0n1werpm/CPHL_EO_2016-2021.xlsx?dl=1"

download.file(url, file.path(inputPath, sub("\\?.+", "", basename(url))), mode = "wb")

file <- file.path(inputPath, "CPHL_EO_2016-2021.xlsx")

dt1 <- as.data.table(read_excel(file))

dt1[, year := as.numeric(substr(date, 1, 4))]
dt1[, month := as.numeric(substr(date, 6, 7))]
dt1[, day := as.numeric(substr(date, 9, 10))]

dt2 <- dt1[month >= 6 & month <= 9, .(ES = exp(mean(log(geomean))), SD = sd(geomean), N = .N * uniqueN(grid_id), NM = uniqueN(month)), keyby = .(UnitID = unit_id, Period = year)]

fwrite(dt2, file.path(inputPath, "Indicator_CPHL_EO_02_2016-2021.csv"))
