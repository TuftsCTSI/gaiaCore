#' Configure offline storage
#'
#' @param dir (string) The directory to be used for offline storage. Default is "/opt/data".
#' @param persist_data (boolean) If TRUE, the downloaded files will persist indefinitely. If FALSE, they will not persist after the session ends. Default is FALSE.
#'
#' @return Copies the storage.yml file to the working directory and configures it with the specified directory and persistence settings. Alternatively, the file can be edited directly.
#'
#' @examples
#' \dontrun{
#'
#' setup_offline_storage(dir = "/path/to/data", persist_data = TRUE)
#' }
#'
#' @export
#'

setup_offline_storage <- function(dir = "/opt/data", persist_data = FALSE) {
    # Copy the storage.yml from inst/config to the working directory
    if (!file.exists("storage.yml")) {
        file.copy("inst/config/storage.yml", "storage.yml", overwrite = TRUE)
    }
    # Edit the storage.yml file to set the directory and change 
    storage_config <- readLines("storage.yml")
    storage_config <- gsub("directory: .*", paste0("directory: ", dir), storage_config)
    writeLines(storage_config, "storage.yml")
    message("storage.yml created with directory: ", dir, ". Local files can now be read from this directory.")
    # If persist_data is TRUE, set up the offline storage directory
    if (persist_data) {
        storage_config <- readLines("storage.yml")
        storage_config <- gsub("persist_data: .*", "persist_data: true", storage_config)
        writeLines(storage_config, "storage.yml")
        # make sure the directory exists
        if (!dir.exists(dir)) {
            dir.create(dir, recursive = TRUE)
            message("Directory created: ", dir)
        }
        message("storage.yml created with persist_data: true. Downloaded files will now be written to this directory and persist indefinitely.")
    } else {    
        message("storage.yml created with persist_data: false. Downloaded files will not persist after the session ends.")
    }
    message("Offline storage setup complete.")
}