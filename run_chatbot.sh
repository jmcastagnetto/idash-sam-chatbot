#! /bin/bash

Rscript -e "library(shiny); runApp('app.R', port = 9090, launch.browser = TRUE)"
