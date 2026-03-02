# RAG Tool Function
# Initializes Ollama chat client for the IDASH SAM chatbot

#' Initialize Ollama Chat Client
#'
#' Sets up the ellmer chat client with Ollama backend
#'
#' @param sys_prompt the system prompt for the model
#' @param model the Ollama model to use
#' @return An ellmer chat client object
#' @export
initialize_ollama_chat <- function(sys_prompt, model) {

  # Check if Ollama is running
  tryCatch({
    response <- httr::GET("http://localhost:11434/api/tags", timeout = 5)
    if (httr::status_code(response) != 200) {
      # log error
      error(
        logger,
        paste("Ollama server is not responding")
      )
      # stop and show error to user
      stop("Ollama server is not responding")
    }
  }, error = function(e) {
    # log error
    error(
      logger,
      paste("Cannot connect to Ollama server:", e$message)
    )
    # stop and show error to user
    stop(paste("Cannot connect to Ollama server:", e$message))
  })


  # Initialize chat client
  chat <- ellmer::chat_ollama(
    system_prompt = sys_prompt, # Set system prompt
    model = model,  # configured LLM model
    params = ellmer::params(
      temperature = 0.1, # minimize stochastic behavior
      max_tokens = 2000,
      top_p = 0.9,
      seed = 42
    )
  )
  info(
    logger,
    "Ollama chat client initialized successfully"
  )
  return(chat)
}
