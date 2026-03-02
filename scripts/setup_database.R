# Database Setup Function
# Initializes connection to the DuckDB knowledge base for RAG operations

#' Setup Ragnar Knowledge Store
#'
#' Initializes a ragnar knowledge store connected to the DuckDB database
#' file containing the IDASH SAM processed material.
#'
#' @param kdb path to duckdb knowledge database
#' @return A ragnar store object
#' @export
setup_ragnar_store <- function(kdb) {

  # Check if database exists
  if (!file.exists(kdb)) {
    # log the error
    error(
      logger,
      paste("Database file not found:", kdb)
    )
    # stop and show error to user
    stop(paste("Database file not found:", kdb))
  }

  # Verify database structure
  tryCatch(
    {
      conn <- DBI::dbConnect(duckdb::duckdb(), kdb, read_only = TRUE)

      # Check that required tables exist
      tables <- DBI::dbListTables(conn)
      required_tables <- c("documents", "chunks",
                           "embeddings", "metadata")

      missing_tables <- setdiff(required_tables, tables)
      if (length(missing_tables) > 0) {
        # log the error
        error(
          logger,
          paste("Missing required tables:",
                paste(missing_tables, collapse = ", "))
        )
        # stop and show error to the user
        stop(
          paste("Missing required tables:",
                paste(missing_tables, collapse = ", "))
        )
      }

    # Get database info
    db_info <- DBI::dbGetQuery(
      conn,
      "SELECT COUNT(*) as doc_count FROM documents"
    )
    chunk_info <- DBI::dbGetQuery(
      conn,
      "SELECT COUNT(*) as chunk_count FROM chunks"
    )

    # inform and log
    info(
      logger,
      sprintf("Database connected: %d documents, %d chunks",
              db_info$doc_count, chunk_info$chunk_count)
    )

    DBI::dbDisconnect(conn)

    },
    error = function(e) {
      # log the error
      error(
        logger,
        paste("Database verification failed:", e$message)
      )
      # stop and show error to the user
      stop(paste("Database verification failed:", e$message))
    }
  ) # tryCatch db structure verification

  # Init ragnar store
  tryCatch(
    {
      store <- ragnar::ragnar_store_connect(kdb)
      info(
        logger,
        "Ragnar store initialized successfully"
      )
      return(store)
    },
    error = function(e) {
      # log the error
      error(
        logger,
        paste("Failed to initialize ragnar store:", e$message)
      )
      # stop and show error to the user
      stop(paste("Failed to initialize ragnar store:", e$message))
    }
  ) # tryCatch ragnar store init
}
