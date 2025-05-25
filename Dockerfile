# Base image with R and system dependencies
FROM rocker/r-ver:4.3.1

# Set environment to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libv8-dev \
    libpng-dev \
    libjpeg-dev \
    libxt-dev \
    libgl1-mesa-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    gdal-bin \
    pandoc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install R dependencies:
COPY /.binder/install.R /src/install.R
RUN Rscript /src/install.R

# Copy the scripts to be called by the OGC processes:
COPY R /R
COPY src /src
WORKDIR /src

# Add an entrypoint that can deal with CLI arguments that contain spaces:
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
