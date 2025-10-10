download_unzip_shapefile_tmp <- function(url) {
  # If the URL points to a zipped shapefile, download and unzip before we can read it:
  if (startsWith(url, 'http') & endsWith(url, 'zip')) {
    message("DEBUG: Downloading and unzipping zipped shapefile: ", url)
    temp_zip <- tempfile(fileext = ".zip")
    download.file(url, temp_zip, mode = "wb")
    unzip(temp_zip, exdir = tempdir())
    shapefile_path <- list.files(tempdir(), pattern = "\\.shp$", full.names = TRUE)
    message("DEBUG: Downloading and unzipping zipped shapefile... DONE.")
  # If the URL points to a non-zipped shapefile, throw error:
  } else if (startsWith(url, 'http') & endsWith(url, 'shp')) {
    stop('If you specify a remote shapefile as input, please zip it...')
  }
  return(shapefile_path)
}


download_unzip_shapefile <- function(url, targetpath) {
  # If the URL points to a zipped shapefile, download and unzip before we can read it:
  # Note: URLs don't have to end on .zip to contain zipped shapefiles, so just try and error:
  #if (startsWith(url, 'http') & endsWith(url, 'zip')) {
  if (startsWith(url, 'http')) {
    message("DEBUG: Downloading zipped shapefile from: ", url)
    message("DEBUG: Downloading zipped shapefile to  : ", targetpath)
    #temp_zip <- tempfile(fileext = ".zip")
    #download.file(url, temp_zip, mode = "wb")
    #unzip(temp_zip, exdir = tempdir())
    download.file(url, targetpath, mode = "wb")
    message("DEBUG: Downloaded... ", url)
    #unzip(targetpath, exdir=dirname(targetpath))
    tryCatch(
      {
        newpath <- unzip(targetpath, exdir=dirname(targetpath))
        message("DEBUG: This was a zip, unzipped to: ", newpath)
        #targetpath <- newpath
      }, error = function(e){
        message("ERROR: This was not a zip: ", targetpath)
        stop('If you specify a remote shapefile as input, please zip it...')
      }, warning = function(e){
        message("WARN: This was not a zip: ", targetpath)
        stop('If you specify a remote shapefile as input, please zip it...')
      }
    )
    message("DEBUG: Unzipped... ", targetpath)
    # Note: The following only works if we only download one shapefile to targetpath, I guess...
    shapefile_path <- list.files(dirname(targetpath), pattern = "\\.shp$", full.names = TRUE)
    message("DEBUG: Downloading and unzipping zipped shapefile... DONE.")
  return(shapefile_path)
  }
}

download_maybe_unzip <- function(url, targetpath) {
  message("DEBUG: Downloading input file from: ", url)
  message("DEBUG: Downloading input file to  : ", targetpath)
  download.file(url, targetpath, mode = "wb")
  tryCatch(
    {
      newpath <- unzip(targetpath, exdir=dirname(targetpath))
      message("DEBUG: This was a zip, unzipped to: ", newpath)
      targetpath <- newpath
    }, error = function(e){
      message("ERROR: This was not a zip: ", targetpath)
    }, warning = function(e){
      message("WARN: This was not a zip: ", targetpath)
    }
  )
  message("DEBUG: DONE: Downloading input file to ", targetpath, " from ", url)
  return(targetpath)
}
