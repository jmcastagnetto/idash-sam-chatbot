# IDASH SAM RAG Chatbot
#
# R-based Retrieval-Augmented Generation Chatbot for IDASH South America
# based on session and reference material from Workshop 1 of Cohort 2
#
# Main application file that provides a chat interface enhanced with RAG capabilities.
# The chatbot retrieves relevant information from a knowledge base of educational
# materials and generates responses using local and cloud LLM models via Ollama.
#
# Features:
# - RAG-enhanced responses with source citations
# - Local processing for privacy
# - Modern responsive UI
#
# Dependencies: See config.yml for required packages and model settings

# Load required libraries
library(shiny)
library(bslib)
library(htmltools)
library(shinychat)
library(ellmer)
library(ragnar)
library(duckdb)
library(DBI)
library(httr)
library(stringr)
library(jsonlite)
library(log4r)
library(config)
library(coro)

# Setup today's log file in JSON format
logfilename <- paste0("logs/", Sys.Date(), "_chatbot-log.json")
logger <- log4r::logger(
  "DEBUG",
  appenders = list(
    # log to console
    log4r::console_appender(),
    # and also to a JSON file
    log4r::file_appender(file = logfilename,
                         layout = log4r::json_log_layout())
  )
)

# mark start of session
info(
  logger,
  "*** NEW SESSION STARTED ***"
)

# Load configuration from config.yml
# Configuration includes database path, model selection,
# system prompts, and retrieval parameters (top_k)
config <- config::get(
  config = "default",
  file = "config.yml"
)

# Extract configuration variables
kdb <- config$kdb              # Path to DuckDB knowledge base
model <- config$model           # Ollama model name (local or cloud)
sys_prompt <- readr::read_file(config$sys_prompt_file)  # System prompt for LLM
welcome <- readr::read_file(config$welcome_file)        # Welcome message for users
# Number of documents to retrieve (default: 5)
if (is.null(config$model_top_k)) { # if not defined
  top_k <- 5
} else {
  top_k <- config$model_top_k
}

# log loading and use of configuration
class(config) <- "list"
info(
  logger,
  paste("Configuration loaded and used:", jsonlite::toJSON(config))
)

# Source utility scripts: for database operations and RAG functionality
source("scripts/setup_database.R")
source("scripts/rag_tools.R")

# Application UI:
# Defines the user interface using Bootstrap theme and shinychat components
# Includes custom styling, responsive design, and accessibility features
# The custom CSS and images are in the "www" directory
ui <- bslib::page_fillable(
  title = "IDASH SAM Chatbot v0.1.0",
  theme = bslib::bs_theme(bootswatch = "cosmo"),
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),
  tags$div(
    class = "app-header",
    h1(tags$img(src = "idash_logo_small.png", width = "84",
                height = "86", alt = "IDASH logo"), "IDASH SAM Chatbot"),
    p("Public Health & Data Science Education Assistant")
  ),
  chat_ui(
    id = "sam_chat",
    messages = welcome,
    placeholder = "Ask me about Public Health and Data Science..."
  ),
  tags$div(
    class = "app-footer",
    p("Powered by Ollama • RAG-enhanced with DuckDB • Content from IDASH SAM Workshop 1"),
    p(
      a("Jesus M. Castagnetto, PhD", href = "https://linktr.ee/jmcastagnetto",
             style = "color: white;"),
      " (2026)",
      style = "text-align: right;"
    )
  ),
  fillable_mobile = TRUE
)

# Application Server Logic:
# Handles all backend operations including database connections,
# LLM interactions, RAG processing, and user message handling
server <- function(input, output, session) {

  # Setup database connection:
  # Connect to DuckDB knowledge base containing IDASH SAM materials
  store <- tryCatch({
    setup_ragnar_store(kdb)
  }, error = function(e) {
    print(e)
    # log error
    error(
      logger,
      paste("Database connection error:", e$message)
    )
    # show error to user
    showNotification(
      paste("Database connection error:", e$message),
                   type = "error", duration = 10)
    return(NULL)
  })
  info(
    logger,
    "Connection to knowldege base successful"
  )

  # Initialize Ollama chat client:
  # Establish connection to local Ollama server for LLM inference
  chat <- tryCatch({
    initialize_ollama_chat(sys_prompt, model)
  }, error = function(e) {
    # log error
    error(
      logger,
      paste("Ollama connection error:", e$message)
    )
    # show error to user
    showNotification(paste("Ollama connection error:", e$message),
                   type = "error", duration = 10)
    return(NULL)
  })
  info(
    logger,
    "Ollama client initialized successfully"
  )


  # Register RAG retrieval tool if connections are successful:
  # Creates a custom tool for the LLM to search the knowledge base
  # This enables the chatbot to provide evidence-based responses with citations
  if (!is.null(store) && !is.null(chat)) {
    tryCatch({
      # Create custom retrieval tool using vector similarity search
      # Fast vector search retrieves most semantically similar documents
      rag_tool <- tool(
        fun = function(query, top_k = top_k) {
          # Sometimes the API is sending the top_k in the form: "[NN]",
          # where NN is a number. Let's try to extract that information first.
          top_k <- as.character(top_k) |>
            stringr::str_extract(pattern = "(\\d+)") |>
            as.integer()
          # Use only vector similarity search (fast)
          results <- ragnar::ragnar_retrieve_vss(
            store = store,
            query = query,
            top_k = top_k
          )

          if (nrow(results) == 0) {
            return("No relevant information found in the knowledge base.")
          }

          # Format results for LLM
          formatted_results <- paste0(
            "Found ", nrow(results), " relevant documents from the IDASH SAM knowledge base:\n\n",
            paste(paste0(
              "Document ", seq_len(nrow(results)), ":\n",
              "Source: ", results$origin, "\n",
              "Content: ", results$text, "\n",
              "---"
            ), collapse = "\n\n")
          )

          return(formatted_results)
        },
        name = "search_idash_knowledge_base",
        description = "Search the IDASH SAM knowledge base for relevant educational materials about Public Health and Data Science. Returns relevant documents with source information.",
        arguments = list(
          query = type_string("The search query to find relevant educational materials"),
          top_k = type_integer("Number of documents to retrieve (default 5, max 10)")
        )
      )

      # Register the custom tool
      chat$register_tool(rag_tool)
    }, error = function(e) {
      # log warning in tool registration
      warning(
        logger,
        paste("RAG tool registration error:", e$message)
      )
      # show warning to user
      showNotification(paste("RAG tool registration error:", e$message),
                      type = "warning", duration = 5)
    })
  }
  info(
    logger,
    "RAG tool registered successfully"
  )

  # Handle user messages
  # Processes incoming user queries, generates responses using RAG-enhanced LLM,
  # and streams responses back to the user interface
  observeEvent(input$sam_chat_user_input, {
    req(chat, store)

    # Get user query
    user_query <- input$sam_chat_user_input
    info(
      logger,
      paste("User query:", user_query)
    )
    tryCatch({
      # Generate response stream directly synchronously
      stream <- chat$stream(user_query, stream = "text")
      # alternative, use async streams, but this will not
      # work with all models
      #stream <- chat$stream_async(user_query)
      answer <- ""
      loop(for (txt in stream) {
        answer <- paste0(answer, txt)
      })
      chat_append("sam_chat", answer)
      info(
        logger,
        paste("Answer:", answer)
      )
      #chat_append("sam_chat", "\n* * *\n")
      {
        tokens <- chat$get_tokens() |>
          dplyr::select(input_preview, input, output) |>
          janitor::adorn_totals(where = "row", name = "*TOTAL*")
        # log token usage
        info(
          logger,
          paste("Token usage:", jsonlite::toJSON(tokens))
        )
        options(knitr.kable.NA = "-")
        chat_append("sam_chat",
              knitr::kable(
                tokens,
                table.attr = "border='1' cellpadding='2'",
                format = "html",
                caption = "Token usage (LLM)"
              )
        )
      }
    }, error = function(e) {
      # log error message
      error(
        logger,
        paste(
          "Error encountered while generating an answer:",
          e$message
        )
      )
      # show error message to the user
      chat_append("sam_chat", paste(
        "**Sorry, I encountered an error:**",
        e$message,
        "\n\nPlease check if Ollama is running and try again."
      ))
    })
  })

  # Add status indicator
  # output$status <- reactive({
  #   if (is.null(store)) {
  #     "Database: Disconnected"
  #   } else if (is.null(chat)) {
  #     "LLM: Disconnected"
  #   } else {
  #     "System: Ready"
  #   }
  # })
  #outputOptions(output, "status", suspendWhenHidden = FALSE)
}

# Run the application:
# Launches the Shiny application with the defined UI and server logic
# The app will be available at http://localhost:9090 by default
shinyApp(ui, server, options = list(port = 9090))
