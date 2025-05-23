# Dockerfile.app
FROM rocker/shiny:latest

# System dependencies for R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
  && rm -rf /var/lib/apt/lists/*

# Copy application files
COPY . /srv/shiny-server/sk8bro
WORKDIR /srv/shiny-server/sk8bro

# Install R package dependencies
RUN Rscript -e "install.packages(c('shiny','shinydashboard','googlesheets4','dplyr','tidyr','plotly','lubridate','DT','rlang','lintr','styler'), repos='https://cloud.r-project.org/')"

# Expose Shiny port
EXPOSE 3838

# Launch the app
CMD ["Rscript","-e","shiny::runApp('.', port=3838, host='0.0.0.0')"]