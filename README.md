# IDASH SAM RAG Chatbot

A Retrieval-Augmented Generation (RAG) chatbot built with R for Public Health and Data Science education. This chatbot provides intelligent responses based on verified educational materials from the IDASH workshop, supporting multiple languages (English, Spanish, Portuguese).

## 🎯 Features

- **RAG-Enhanced Responses**: Retrieves relevant content from a curated database of educational materials
- **Multilingual Support**: Responds in English, Spanish, or Portuguese via LLM
- **Local Processing**: Runs entirely locally using ollama for privacy and cost efficiency
- **Source Citation**: Always cites the educational materials used in responses
- **Educational Focus**: Specialized in Informatics and Data Science applied to Public Health, using the material from Workshop 1 of IDASH SAM (cohort 2)
- **Usable UI**: Clean, responsive interface built with Shiny and shinychat
- **Logging**: Logging of sessions and responses

## 🏗️ Architecture

```
IDASH SAM RAG Chatbot
├── Frontend (shinychat)     # Chat interface
├── LLM Backend (ellmer)     # ollama integration
├── RAG Engine (ragnar)      # Retrieval from DuckDB
└── Knowledge Base (duckdb)  # 32,244 pre-embedded chunks
```

### Key Components

1. **DuckDB Database**: Pre-populated with 227 educational documents (32,244 chunks)
2. **Vector Embeddings**: 768-dimensional embeddings for semantic search
3. **Vector Search**: Fast similarity-based retrieval from DuckDB
4. **Citation System**: Complete source attribution for all responses

## 📋 Prerequisites

### System Requirements

- **R (4.3+)**: Latest R installation
- **ollama**: Local LLM server running on port 11434
- **8GB+ RAM**: Recommended for local LLM processing
- **Storage**: 2GB+ for database and models

### Required R Packages

```r
# Install CRAN packages
install.packages(c(
  "shiny", "bslib", "htmltools",
  "duckdb", "DBI", "httr", "jsonlite",
  "stringr", "config", "readr",
  "log4r", "coro",
  "ellmer", "ragnar", "shinychat"
))
```

### ollama Setup

1. **Install ollama**:

   ```bash
   # macOS/Linux
   curl -fsSL https://ollama.com/install.sh | sh

   # Or follow instructions from from https://ollama.com
   ```

2. **Start ollama Server**:

   ```bash
   ollama serve
   ```

3. **Pull Required Embeding Model, and other models**:

   ```bash
   # RAG embedding model (required)
   ollama pull nomic-embed-text-v2-moe:latest

   # Alternative get local models for chatbot
   ollama pull qwen2.5:7b
   ollama pull llama3.2:3b
   ollama pull qwen3.5:4b
   # Alternative cloud models for chatbot
   # these require having an ollama account
   ollama pull gpt-oss:20b-cloud
   ollama pull glm-4.7:cloud
   ollama pull ministral-3:14b-cloud
   # or any other model with tools support
   ```

## 🚀 Quick Start

### 1. Clone/Download the Project

```bash
git clone https://github.com/jmcastagnetto/idash-sam-chatbot.git
cd idash-sam-chatbot
```

### 2. Verify Database

Because the processed database is over the github limits (407MB), you
need to get it from [my cloud storage](https://e.pcloud.link/publink/show?code=XZUNM3ZPlsek1kj7YYzVQv2kwv1HLnDyHN7)
and save it in `db/idash_sam_ragnar.duckdb`.

You might want to verify that you downloaded the database correctly,
using:

```bash
$ sha256sum db/idash_sam_ragnar.duckdb
13ff79c45ba3536ceeda9f67594316226f09d8b7a5d9194f488bd52663256b5c  db/idash_sam_ragnar.duckdb
```

Also, if you want to verify that you can connect to it using R console, you can use:

```r
library(duckdb)
db <- duckdb("db/idash_sam_ragnar.duckdb")
connect <- dbConnect(db)
dbGetQuery(connect, "SELECT count(*) from documents;")
```

And you should get as output:

```
  count_star()
1          227
```

### 3. Start ollama

Make sure ollama is running:

```bash
# Terminal 1
ollama serve

# Terminal 2 (optional, to check available models)
ollama list
```

### 4. Run the Application

```r
# In R console
shiny::runApp()
```

The application will open in your browser at `http://localhost:3838`

## 📁 Project Structure

```
idash-sam-chatbot/
├── app.R                        # Main Shiny application
├── config.yml                   # Configuration file (model, database paths)
├── scripts/
│   ├── setup_database.R         # Database connection functions
│   ├── rag_tools.R              # RAG retrieval and processing
├── www/
│   ├── custom.css               # Application styling
│   ├── idash_logo.png           # IDASH logo
│   └── idash_logo_small.png     # Small IDASH logo
├── db/
│   └── idash_sam_ragnar.duckdb  # Knowledge base (separate download)
├── logs/                        # Directory for log files
├── _system_prompt.txt           # Model system prompt
├── _welcome.txt                 # Welcome message
├── check_setup.sh               # Bash script to check if everything is OK
├── validate_reqs.R              # Requisites validation, use by check_setup.sh
├── idash-sam-chatbot.Rproj      # RStudio project file
├── LICENSE                      # MIT license
├── VERSION                      # Version tag
└── README.md                    # This documentation
```

## 🧠 Knowledge Base

### Database Contents

- **Documents**: 227 training materials from workshop 1 of IDASH SAM
- **Chunks**: 32,244 text segments
- **Languages**: English, Spanish, Portuguese
- **File Types**: PDFs (90), PowerPoint (77), Quarto (23), Word (21), HTML (16)
- **Topic Focus**: IDASH Workshop 1 - Public Health and Data Science

### Content Quality

All content has been:

- Pre-processed with 768-dimensional embeddings
- Chunked for optimal retrieval
- Indexed for semantic search
- Verified for educational quality

## 🌍 Multilingual Features

### Supported Languages

1. **English**
2. **Spanish**
3. **Portuguese**

### Language Handling

The chatbot leverages the LLM's built-in multilingual capabilities to detect and respond in the appropriate language based on the system prompt.

## 🔧 Configuration

The application uses `config.yml` for centralized configuration:

```yaml
default:
  kdb: "db/idash_sam_ragnar.duckdb"
  sys_prompt_file: "_system_prompt.txt"
  welcome_file: "_welcome.txt"
  model: "qwen3:4b"  # LLM model selected
  model_top_k: 5    # numer of documents to retrieve
```

### Validation Script

Run the validation script to check system health:

```bash
./check_setup.sh
```

This script uses `validate_setup.R` and checks that:

- The required files exist
- The required R packages are installed
- There is database connectivity
- The ollama server is running
- The selected LLM model is available

## 🐛 Troubleshooting

### Common Issues

#### 1. ollama Connection Failed

**Symptoms**: "Cannot connect to ollama server" error

**Solutions**:

```bash
# Check if ollama is running
ps aux | grep ollama

# Start ollama service
ollama serve

# Check port availability
curl http://localhost:11434/api/tags
```

#### 2. Model Not Found

**Symptoms**: "Model not found" error

**Solutions**:

```bash
# List available models
ollama list

# Pull required model
ollama pull qwen3:4b

# Check model status
ollama show qwen3:4b
```

#### 3. Database Connection Error

**Symptoms**: "Database file not found" or connection errors

**Solutions**:

```r
# Check database exists
file.exists("db/idash_sam_ragnar.duckdb")

# Test database connection (requires DB to exist)
library(duckdb)
library(DBI)
conn <- DBI::dbConnect(duckdb::duckdb(), "db/idash_sam_ragnar.duckdb", read_only = TRUE)
DBI::dbGetQuery(conn, "SELECT COUNT(*) as count FROM documents")
DBI::dbDisconnect(conn)
```

#### 4. Memory Issues

**Symptoms**: Slow responses, system lag

**Solutions**:

- Use smaller models (mistral:7b instead of llama3.1:8b)
- Close other memory-intensive applications
- Consider GPU acceleration if available

### Debug Mode

Enable debugging by adding to `app.R`:

```r
# At the top of server function
options(shiny.trace = TRUE)
options(shiny.fullstacktrace = TRUE)
```

## 🔒 Security & Privacy

### Data Privacy

- **Local Processing**: All processing happens locally on your machine
- **No External APIs**: Only connects to a local ollama server
- **No Data Collection**: No data is sent to external services
- **Citation Transparency**: All sources are fully attributed

### Security Considerations

- **Network Access**: Application only accesses local ollama (localhost:11434)
- **File Access**: Read-only access to database files
- **No Authentication**: Local application, no user authentication required

### Sample Test Queries

**English**:

- "What is public health surveillance?"
- "How is machine learning used in epidemiology?"
- "Explain data governance for health data"

**Spanish**:

- "¿Qué es la vigilancia en salud pública?"
- "¿Cómo se usa el aprendizaje automático en epidemiología?"
- "Explique la gobernanza de datos de salud"

**Portuguese**:

- "O que é vigilância em saúde pública?"
- "Como usar machine learning em epidemiologia?"
- "Explique a governança de dados de saúde"

## 📚 API Reference

### Core Functions

#### Database Functions (`scripts/setup_database.R`)

- `setup_ragnar_store()`: Initialize database connection to DuckDB

#### RAG Functions (`scripts/rag_tools.R`)

- `initialize_ollama_chat()`: Setup ollama chat client

## 📄 License

This project is part of the IDASH South American (SAM) Program, and is available
under an [MIT license](LICENSE).

---

**Built with ❤️ for the IDASH South America Program**
