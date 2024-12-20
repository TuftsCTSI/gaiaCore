# gaiaCore

### WARNING: this package is under-development and has only been tested using mock data

# Introduction
An R Package for interacting with gaiaDB - part of the OHDSI GIS **Gaia** toolchain

# Get Started

Install the latest version of the package from GitHub:
```R
# install.packages('remotes')
remotes::install_github("ohdsi/gaiaCore")
```

Connect to gaiaDB:
```R
library(gaiaCore)

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/gaiaDB",
  port = 5432,
  user="postgres",
  password = "mysecretpassword") 
```

# Support
-   Please use the <a href="../../issues">GitHub issue tracker</a> for all bugs, issues, and feature requests
