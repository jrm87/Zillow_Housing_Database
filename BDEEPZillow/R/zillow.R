# This file contains functions for data transfer between R and PostgreSQL database: get_from_db_*.
# For more information about package RPostgreSQL, see https://cran.r-project.org/web/packages/RPostgreSQL/RPostgreSQL.pdf

#' get_from_db_state
#' @description This function gets a list of data.frames from the database, according to the given
#'              states (through abbreviation).
#' @param states_abbr   A vector of states fips
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @param max_num_recs  An integer indicating the maximum number of records to select,
#'                      -1 indicating all (by default)
#' @param database_name A string indicating the database name
#' @param host_ip       A string indicating the ip address of the database VM
#' @param append        If append is true, return a single data.frame with rows appended, otherwise a
#'                      list of data.frames from each state.
#' @examples  data <- get_from_db_state("sd")
#' @examples  data <- get_from_db_state(c("sD","Ne"), append=FALSE)
#' @examples  data <- get_from_db_state("ca",columns=c("rowid","transid"))
#' @examples  data <- get_from_db_state("sd",max_num_recs=100)
#' @return If input is a single state, return a single data.frame. If input is a vector and append = F,
#'         return a list of data.frames, in the same order of that in states_abbr, otherwise the result
#'         is appended into one whole data.frame.
#' @import RPostgreSQL DBI
#' @export
get_from_db_state <- function(states_abbr, columns="*", max_num_recs=-1, database_name="zillow_2017_nov",
                              host_ip="db1.econ.duke.edu", append=TRUE){
  print("Connecting to database:")
  # Make sure states_abbr are lower cased
  states_abbr <- tolower(states_abbr)
  # Gets database driver, assuming PostgreSQL database
  drv <- DBI::dbDriver("PostgreSQL")
  # Creates a connection to the postgres database
  # Note that "con" will be used later in each connection to the database
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = database_name,
                                host = host_ip,
                                port = 5432,
                                user = "zrw",
                                password = "thezillowdance")
  print("Connected! Now extracting data...")
  # Get input length
  len <- length(states_abbr)
  # Create returned list
  hedonics <- list()
  # Get data from database
  for (i in 1:len){
    state <- states_abbr[i]
    # ignore non-existing states & check for the table
    if(!RPostgreSQL::dbExistsTable(con, c("hedonics_new", paste0("hedonics_",state)))){
      print(paste("Skipping State:", state))
      next
    }
    print(paste("Processing State:", state))
    options(warn = -1)    # suppress warning messages
    if(max_num_recs < 0){
      hedonics[[i]] <- RPostgreSQL::dbGetQuery(con,
                                               paste0("SELECT ",
                                                      paste(columns, collapse = ","),
                                                      " FROM hedonics_new.",
                                                      "hedonics_",
                                                      state))
    } else {
      hedonics[[i]] <- RPostgreSQL::dbGetQuery(con,
                                               paste0("SELECT ",
                                                      paste(columns, collapse = ","),
                                                      " FROM hedonics_new.",
                                                      "hedonics_",
                                                      state,
                                                      " FETCH FIRST ",
                                                      max_num_recs,
                                                      " ROWS ONLY"))
    }
    options(warn = 0)
    # Garbage collection
    gc()
  }
  # Close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  # Return a list if more than one input states
  print("Finished!")
  if(len==1){
    return(db_type_converter(hedonics[[1]], dbname=database_name))
  } else if(append){
    return(db_type_converter(do.call("rbind", hedonics), dbname=database_name))
  } else{
    return(db_type_converter(hedonics, dbname=database_name))
  }
}

#' get_from_db_state_county
#' @description This function gets a data.frame including all data from the given state abbr. and county.
#' @param state_county  A data.frame with two columns representing state and county name
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @param database_name A string indicating the database name
#' @param host_ip       A string indicating the ip address of the database VM
#' @param append        If append is true, return a single data.frame with rows appended, otherwise a
#'                      list of data.frames from each state.
#' @examples # First we need to get a data.frame as input to the get_from_db_state_county function.
#' @examples # The following returns a data.frame with columns representing state and county
#' @examples table <- get_state_county_by_fips("01001")[, c("state","county")]
#' @examples # Next we feed it into the function to get hedonics data
#' @examples data <- get_from_db_state_county(table)
#' @return A data.frame including all data from the given state and county
#' @import RPostgreSQL DBI
#' @export
get_from_db_state_county <- function(state_county, columns="*", database_name="zillow_2017_nov",
                                     host_ip="db1.econ.duke.edu", append=TRUE){
  # Check valid input
  if(nrow(state_county)==0 || ncol(state_county)!=2 || any(nchar(as.character(state_county[,1]))!=2)){
    print("Invalid argument! Please input variable state_county as followed:")
    print(get_state_county_by_fips("01001")[, c("state","county")])
    return(NULL)
  }
  # Initialize list for return
  hedonics <- list()
  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = database_name,
                                host = host_ip,
                                port = 5432,
                                user = "zrw",
                                password = "thezillowdance")
  # Process state-county sequentially
  options(warn = -1)    # suppress warning messages
  for(i in 1:nrow(state_county)){
    print(paste("Processing state", toupper(state_county[i, 1]), "county", state_county[i, 2]))
    hedonics[[i]] <- RPostgreSQL::dbGetQuery(con, paste0("SELECT ",
                                                         paste(columns, collapse = ","),
                                                         " FROM hedonics_new.",
                                                         "_hedonics",
                                                         tolower(state_county[i, 1]),
                                                         " WHERE county='",
                                                         toupper(state_county[i, 2]),
                                                         "'"))
    gc()
  }
  options(warn = 0)
  # Close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  # Construct returned hedonics
  print("Finished!")
  if(append){
    return(db_type_converter(do.call("rbind", hedonics), dbname=database_name))
  } else {
    return(db_type_converter(hedonics, dbname=database_name))
  }
}

#' get_from_db_fips
#' @description This function gets a data.frame including all data from the given fips. Use previous
#'              function.
#' @param fips          A vector of fips
#' @param columns       A vector of column names to export. Default to all columns (i.e. "*").
#' @param database_name A string indicating the database name
#' @param host_ip       A string indicating the ip address of the database VM
#' @param append        If append is true, return a single data.frame with rows appended, otherwise a
#'                      list of data.frames from each state.
#' @examples data <- get_from_db_fips("10001")
#' @examples data <- get_from_db_fips(c("01001","17019"))
#' @return A data.frame including all data from the given fips.
#' @import RPostgreSQL DBI
#' @export
get_from_db_fips <- function(fips, columns="*", database_name="zillow_2017_nov",
                             host_ip="db1.econ.duke.edu", append=TRUE){
  sc <- get_state_county_by_fips(fips)[, c("state","county")]
  return(get_from_db_state_county(sc,
                                  columns=columns,
                                  database_name=database_name,
                                  host_ip=host_ip,
                                  append=append))
}

#' get_from_db_usr
#' @description This function gets from database according to a user-specified query.
#' @param query         A string specifying the query sent to database
#' @param database_name A string indicating the database name
#' @param host_ip       A string indicating the ip address of the database VM
#' @examples # Select single field from a given table
#' @examples data <- get_from_db_usr("SELECT loadid FROM hedonics_new.hedonics_sd")
#'
#' @examples # Select multiple fields from a given table
#' @examples data <- get_from_db_usr("SELECT loadid, transid FROM hedonics_new.hedonics_sd")
#'
#' @examples # Select limited rows from a given table
#' @examples data <- get_from_db_usr("SELECT * FROM hedonics_new.hedonics_sd limit 10")
#'
#' @examples # Select a 'bounding box' from a given table
#' @examples data <- get_from_db_usr("SELECT * FROM hedonics_new.hedonics_sd WHERE (propertyaddresslatitude BETWEEN 44.35 AND 44.36) AND (propertyaddresslongitude BETWEEN -98.22 AND -98.21)")
#'
#' @examples # Select from a list for a column (columns) in a given table
#' @examples get_from_db_usr("SELECT * FROM hedonics_new.hedonics_sd WHERE county IN ('BEADLE', 'UNION')")
#'
#' @examples # Get the number of records (rows) in a given table
#' @examples get_from_db_usr("SELECT count(*) FROM hedonics_new.hedonics_sd")
#'
#' @examples # Get the range of a specific field
#' @examples get_from_db_usr("SELECT min(propertyaddresslatitude), max(propertyaddresslatitude) FROM hedonics_new.hedonics_sd")
#' @return A data.frame returned by the given query.
#' @import RPostgreSQL DBI
#' @export
get_from_db_usr <- function(query, database_name="zillow_2017_nov", host_ip="db1.econ.duke.edu"){
  # Only one query at a time is supported
  if(length(query)>1){
    print("Only one query at a time is supported!")
    return(NULL)
  }
  # Initialize connection
  drv <- DBI::dbDriver("PostgreSQL")
  con <- RPostgreSQL::dbConnect(drv,
                                dbname = database_name,
                                host = host_ip,
                                port = 5432,
                                user = "zrw",
                                password = "thezillowdance")
  # Get data
  options(warn = -1)    # suppress warning messages
  hedonics <- RPostgreSQL::dbGetQuery(con, query)
  options(warn = 0)
  gc()
  # Close the connection
  RPostgreSQL::dbDisconnect(con)
  RPostgreSQL::dbUnloadDriver(drv)
  return(db_type_converter(hedonics, dbname=database_name))
}
