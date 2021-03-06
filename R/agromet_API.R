#----
#' Retrieve data from the [AGROMET API](https://app.pameseb.be/fr/pages/api_call_test/).
#' @import dplyr
#' @import magrittr
#' @param user_token.chr A character specifying your user token
#' @param table_name.chr A character specifying the database table you want to query
#' @param user_token.chr A character specifying your user token
#' @param sensors.chr A character vector containing the names of the sensors you want to query
#' @param stations_ids.chr A character vector containing the ids of the stations you want to query
#' @param dfrom.chr A character specifying the data from which you want to query data (YYYY-MM-DD)
#' @param dto.chr A character specifying the data to which you want to query data (YYYY-MM-DD)
#' @param month_day.chr A character specifying the month and day from which you want TMY data (MM-DD)
#' @param api_v.chr A character specifying the version of the API you want to use ("v1" or "v2")
#' @param test.bool A boolean, TRUE if you want to query the test server
#' @return A list containing the metadata in the first element and the queried data in the second element
#' @export
get_from_agromet_API.fun <- function(
  user_token.chr=NULL,
  table_name.chr=NULL,
  sensors.chr=NULL,
  stations_ids.chr,
  dfrom.chr=NULL,
  dto.chr=NULL,
  month_day.chr=NULL,
  api_v.chr=NULL,
  test.bool=FALSE
){

  # Defining the base URL for API calls
  baseURL.chr <- "https://app.pameseb.be/agromet/api"
  if(test.bool == TRUE){
    baseURL.chr <- "https://testapp.pameseb.be/agromet/api"
  }

  # Clean the eventual spaces in the sensors.chr string
  if(!is.null(sensors.chr)){
    sensors.chr <- gsub(" ","",sensors.chr)
  }

  # Build the proper table API call URL
  if(table_name.chr=="get_rawdata_irm"){
    api_table_url.chr <- paste(baseURL.chr, api_v.chr, table_name.chr, sensors.chr, stations_ids.chr, dfrom.chr, dto.chr, sep="/")
  }
  if(table_name.chr=="station"){
    api_table_url.chr <- paste(baseURL.chr, api_v.chr, table_name.chr, stations_ids.chr,  sep="/")
  }
  if(table_name.chr=="cleandata"){
    api_table_url.chr <- paste(baseURL.chr, api_v.chr, table_name.chr, sensors.chr, stations_ids.chr, dfrom.chr, dto.chr, sep="/")
  }
  if(table_name.chr=="get_tmy"){
    api_table_url.chr <- paste(baseURL.chr, api_v.chr, table_name.chr, sensors.chr, stations_ids.chr, month_day.chr, sep="/")
  }
  if(table_name.chr=="get_rawdata_dssf"){
    api_table_url.chr <- paste(baseURL.chr, api_v.chr, table_name.chr, dfrom.chr, dto.chr, "dailygeojson", sep="/")
  }
  cat(paste("your API URL call is : ", api_table_url.chr, " \n "))

  # Add your user token into the HTTP authentication header and call API (https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization)
  api_table_req.resp <- httr::GET(api_table_url.chr, httr::add_headers("Authorization" = paste("Token", user_token.chr, sep=" ")))

  if(api_table_req.resp$status_code!=200){
    stop(paste0("The API responded with an error ", api_table_req.resp$status_code, ". Function execution halted. \n Please check your token and the validity + order of the parameters you provided. API documentation available at https://app.pameseb.be/fr/pages/api_call_test/ " ))
  }
  cat(paste0("The API responded with a status code ", api_table_req.resp$status_code, ". Your requested data has been downloaded \n"))

  # Getting the JSON data from the API response
  api_results_json.chr <- httr::content(api_table_req.resp, as = "text")

  # Transform the JSON response to R-friendly list format
  results.l <- jsonlite::fromJSON(api_results_json.chr)

  # Remove the terms of service and version info to only keep the data
  if(table_name.chr != "get_rawdata_dssf" ){
    results.df <- results.l$results
  }else{
    results.df <- results.l$features

    # make each feature properties a list element
    date_ens.l <- results.df$properties
    date_ens.l <- purrr::imap(date_ens.l, function(x, sid) cbind(x, sid))

    coords.l <- results.df$geometry$coordinates
    coords.l <- lapply(coords.l, function(x) as.data.frame(t(x)))
    coords.l <- purrr::imap(coords.l, function(x, sid) cbind(x, sid))

    # join each feature coordinates + properties
    # https://stackoverflow.com/questions/44703738/merge-two-lists-of-dataframes
    results.df <- purrr::map2_df(date_ens.l, coords.l, dplyr::left_join, by="sid")
    colnames(results.df) <- c("mhour", "ens", "sid", "lat", "lon")
  }

  # check if we do not have results for this query, stop the execution
  if(class(results.df) != "data.frame"){
    stop(paste0("There are no records for this query. Function execution halted. \n Please provide another date Range and/or parameters input" ))
  }

  # Rename the column "station" to "id" for later clarity of the code only if the API returns results
  # colnames(results.df)[which(names(results.df) == "station")] <- "id"

  # Create a dataframe for the stations meta-information
  stations_meta.df <- results.l$references$stations

  # The query with table = station does not provide records but only metadata stored in records.df
  if(table_name.chr == "station"){
    stations_meta.df <- results.df
    results.df <- NULL
  }

  # Group in a list
  results_and_stations_meta.l <- list(stations_meta.df = stations_meta.df, records.df = results.df)

  # Present a quick overview of the results in the console
  cat("Overview of the queried results : \n")
  print.data.frame(head(results_and_stations_meta.l$records.df))

  # Return the results and the station_meta dataframes stored in as a list
  return(results_and_stations_meta.l)
}


#----
#' Prepare the data obtained by get_from_agromet_api.fun(). It types all the character variables to their proper types.
#' @import dplyr
#' @import magrittr
#' @param  meta_and_records.l a list containing agromet records and metadata returned by get_from_agromet_api.fun().
#' @param table_name.chr a character specifying the name of the agromet table from which the data where called using get_from_agromet_api.fun()
#' @return a typed dataframe
#' @export
prepare_agromet_API_data.fun  <- function(meta_and_records.l, table_name.chr=NULL){

  # declaration of the function to convert sunrise and sunset columns to chron objects
  convertSun <- function(sunHour.chr){

    # transform to datetime format
    sunHour.posix <- strptime(x = sunHour.chr, format = "%H:%M:%S")

    # only keep the hour part using library chron
    sunHour.chron <- chron::times(format(sunHour.posix, "%H:%M:%S"))

    # retourn the sunHour.chron object
    return(sunHour.chron)
  }

  # Create the vector of all the existing sensors in the Agromet db
  sensors.chr <- c("tsa", "tha", "hra", "tsf", "tss", "ens", "dvt", "vvt", "plu", "hct", "ts2", "th2", "hr2")

  # Create the stations positions df
  stations_meta.df <- meta_and_records.l[[1]]

  # Create the records df
  records.df <- meta_and_records.l[[2]]

  # In stations_meta.df, tmy_period information are stored as df stored inside df. We need to extract these from this inner level and add as new columns
  tmy_period.df <- stations_meta.df$metadata$tmy_period

  if(table_name.chr != "get_rawdata_dssf"){
    stations_meta.df <- stations_meta.df %>% dplyr::select(-metadata)
    stations_meta.df <- bind_cols(stations_meta.df, tmy_period.df)
    # Transform from & to column to posix format for easier time handling
    data.df <- stations_meta.df %>%
      dplyr::mutate_at("from", as.POSIXct, format = "%Y-%m-%dT%H:%M:%S", tz = "GMT-2") %>%
      dplyr::mutate_at("to", as.POSIXct, format = "%Y-%m-%dT%H:%M:%S", tz = "GMT-2")
  }else{
    data.df <- NULL
  }

  if(!is.null(records.df)){
    # Join stations_meta and records by "id"
    if(!is.null(data.df)){
      records.df <- dplyr::left_join(data.df, records.df, by=c("sid"))
    }

    # Transform sid and id columns from character to numeric
    records.df <- records.df %>% dplyr::mutate_at(vars(one_of(c("sid", "id"))), dplyr::funs(as.numeric))

    # Transform mtime column to posix format for easier time handling
    records.df <- records.df %>% dplyr::mutate_at(vars(one_of(c("mtime", "mhour"))), as.POSIXct, format = "%Y-%m-%dT%H:%M:%SZ")

    # Transform meta altitude, longitude, latitude columns from character to numeric
    records.df <- records.df %>% dplyr::mutate_at(vars(one_of(c("altitude", "longitude", "latitude", "lon", "lat"))), dplyr::funs(as.numeric))

    if(table_name.chr != "get_rawdata_dssf"){
      # Transform sensors.chr columns from character to numeric values
      records.df <- records.df %>% dplyr::mutate_at(vars(one_of(sensors.chr)), dplyr::funs(as.numeric))

      # Transform sunrise/sunset columns to times format for easier time handling
      if(!is.null(records.df$sunrise)){
        records.df <- records.df %>% dplyr::mutate_at(c("sunrise","sunset"), convertSun)
      }
    }
  }

  # Return the properly typed and structured records dataframe.
  return(records.df)
}
