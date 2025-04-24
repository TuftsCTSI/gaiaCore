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
-   Please use the <a href="https://github.com/OHDSI/gaiaCore/issues?q=sort%3Aupdated-desc+is%3Aissue+is%3Aopen">GitHub issue tracker</a> for all bugs, issues, and feature requests

# Details
## Offline Storage

Offline storage can be set up for the purpose of loading local datasets in gaiaDB and persisting downloaded source datasets.

Offline storage is configured using a file `storage.yml` to specify a directory and whether or not to persist downloaded datasets.

You can create this file using the helper function `setup_offline_storage()`:

```R
setup_offline_storage(dir = "/path/to/data", persist_data = TRUE)
```

The above command will create a file named `storage.yml` in your working directory. It will also create a directory `path/to/data` if one does not already exist. Any datasets downloaded using `loadGeometry()` or `loadVariable()` will be saved to this directory!