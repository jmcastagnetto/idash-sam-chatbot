#!/usr/bin/env Rscript
# This script validates that all components are properly set up for the
# IDASH SAM RAG Chatbot application.
#
# Validation Checks:
# 1. Required files existence
# 2. R package installation
# 3. Database connectivity
# 4. Ollama server availability
# 5. Model availability
#
# Usage: Rscript validate_setup.R

cat("+++ IDASH SAM RAG Chatbot Validation +++\n\n")

# Check required files
required_files <- c(
  "app.R",
  "scripts/setup_database.R",
  "scripts/rag_tools.R",
  "www/custom.css",
  "www/idash_logo_small.png",
  "db/idash_sam_ragnar.duckdb"
)

cat("Checking required files...\n")
all_files_exist <- TRUE
for (file in required_files) {
  if (file.exists(file)) {
    cat("✓", file, "\n")
  } else {
    cat("✗", file, " - MISSING\n")
    all_files_exist <- FALSE
  }
}

# Check R packages
cat("\nChecking R packages...\n")
required_packages <- c("shiny", "bslib", "htmltools", "duckdb", "DBI",
                      "httr", "jsonlite", "stringr", "shinychat", "ellmer", "ragnar",
                      "log4r", "config", "coro")

all_packages_installed <- TRUE
for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("✓", pkg, "\n")
  } else {
    cat("✗", pkg, " - NOT INSTALLED\n")
    all_packages_installed <- FALSE
  }
}

# Check database connectivity
cat("\nChecking database connectivity...\n")
if (file.exists("db/idash_sam_ragnar.duckdb")) {
  tryCatch({
    library(duckdb)
    library(DBI)
    conn <- dbConnect(duckdb::duckdb(), "db/idash_sam_ragnar.duckdb", read_only = TRUE)
    result <- dbGetQuery(conn, "SELECT COUNT(*) as count FROM documents")
    dbDisconnect(conn)
    cat("✓ Database connection successful (", result$count, " documents)\n")
  }, error = function(e) {
    cat("✗ Database connection failed:", e$message, "\n")
  })
} else {
  cat("✗ Database file not found\n")
}

# Check Ollama availability
cat("\nChecking Ollama availability...\n")
tryCatch({
  response <- httr::GET("http://localhost:11434/api/tags", timeout = 5)
  if (httr::status_code(response) == 200) {
    cat("✓ Ollama server is running\n")
    models <- httr::content(response, "parsed", encoding = "UTF-8")$models
    all_models <- c()
    for (i in 1:length(models)) {
      all_models <- c(all_models, models[[i]]$name)
    }
    if (length(models) > 0) {
      cat(paste0("  Available models (N=", length(models) ,"):\n"),
          paste("\t> ", all_models, collapse = "\n"), "\n")
    } else {
      cat("  No models available - consider running: ollama pull qwen2.5:cpu\n")
    }
  } else {
    cat("✗ Ollama server responded with error\n")
  }
}, error = function(e) {
  cat("✗ Ollama server not running - start with: ollama serve\n")
})

# Summary
cat("\n=== Validation Summary ===\n")
if (all_files_exist && all_packages_installed) {
  cat("✓ Core setup is complete!\n")
  cat("\nTo run the application:\n")
  cat("1. Start Ollama: ollama serve\n")
  cat("2. Pull model: ollama pull qwen3:4b\n")
  cat("3. Run app: R -e 'shiny::runApp()'\n")
  cat("\nApplication will be available at: http://localhost:3838\n")
} else {
  cat("⚠ Please fix the issues above before running the application\n")
}

cat("\n+++ Validation Complete +++\n")
