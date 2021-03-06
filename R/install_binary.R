#' Install a R binary package
#'
#' @param filename filename of built binary package to install
#' @param lib library to install packages into
#' @param metadata Named character vector of metadata entries to be added
#'   to the \code{DESCRIPTION} after installation.
#' @importFrom archive archive archive_extract
#' @importFrom filelock lock unlock
#' @importFrom rlang cnd cnd_signal
#' @export
install_binary <- function(filename, lib = .libPaths()[[1L]],
                           metadata = NULL) {

  now <- Sys.time()

  desc <- verify_binary(filename)
  pkg_name <- desc$get("Package")

  if (is_loaded(pkg_name)) {
    warn(type = "runtime_error",
     "Package {pkg_name} is already loaded, installing may cause problems.
      Use `pkgload::unload({pkg_name})` to unload it.",
     package = pkg_name)
  }

  lib_cache <- library_cache(lib)
  lockfile <- lock_cache(lib_cache, pkg_name, getOption("install.lock"))
  on.exit(unlock(lockfile))

  pkg_cache_dir <- file.path(lib_cache, pkg_name)
  if (file.exists(pkg_cache_dir)) {
    unlink(pkg_cache_dir, recursive = TRUE, force = TRUE)
  }

  archive_extract(filename, dir = lib_cache)
  add_metadata(file.path(lib_cache, pkg_name), metadata)

  installed_path <- file.path(lib, pkg_name)
  if (file.exists(installed_path)) {
    # First move the existing library (which still works even if a process has
    # the DLL open), then try to delete it, which may fail if another process
    # has the file open.
    move_to <- file.path(create_temp_dir(), pkg_name)
    ret <- file.rename(installed_path, move_to)
    if (!ret) {
      abort(type = "filesystem",
        "Failed to move installed package at {installed_path}",
        package = pkg_name)
    }
    ret <- unlink(move_to, recursive = TRUE, force = TRUE)
    if (ret != 0) {
      warn(type = "filesystem",
        "Failed to remove installed package at {move_to}",
        package = pkg_name)
    }
  }
  ret <- file.rename(pkg_cache_dir, installed_path)
  if (!ret) {
    abort(type = "filesystem",
      "Unable to move package from {pkg_cache_dir} to {installed_path}",
      package = pkg_name)
  }

  cnd_signal(
    cnd("pkginstall_installed",
      package = pkg_name, path = installed_path, time = Sys.time() - now, type = "binary"))

  installed_path
}


get_pkg_name <- function(tarball) {
  if (!inherits(tarball, "archive")) {
    tarball <- archive(tarball)
  }

  filename <- attr(tarball, "path")

  description_path <- grep("DESCRIPTION$", tarball$path, value = TRUE)

  # If there is more than one DESCRIPTION in the tarball use the shortest one,
  # which should always be the top level DESCRIPTION file.
  # This may happen if there are test packages in the package tests for instance.
  description_path <- head(description_path[order(nchar(description_path))], n = 1)

  if (length(description_path) == 0) {
    abort(type = "invalid_input", "
      {filename} is not a valid binary, it does not contain a `DESCRIPTION` file.
      ")
  }

  pkg <- dirname(description_path)

  nested_directory <- dirname(pkg) != "."
  if (nested_directory) {
    abort(type = "invalid_input", "
      {filename} is not a valid binary, the `DESCRIPTION` file is nested more than 1 level deep {description_path}.
      ")
  }
  pkg
}

#' @importFrom utils modifyList
add_metadata <- function(pkg_path, metadata) {
  if (!length(metadata)) return()

  ## During installation, the DESCRIPTION file is read and an package.rds
  ## file created with most of the information from the DESCRIPTION file.
  ## Functions that read package metadata may use either the DESCRIPTION
  ## file or the package.rds file, therefore we attempt to modify both of
  ## them, and return an error if neither one exists.

  source_desc <- file.path(pkg_path, "DESCRIPTION")
  binary_desc <- file.path(pkg_path, "Meta", "package.rds")
  if (file.exists(source_desc)) {
    do.call(desc::desc_set, c(as.list(metadata), list(file = source_desc)))
  }

  if (file.exists(binary_desc)) {
    pkg_desc <- base::readRDS(binary_desc)
    desc <- as.list(pkg_desc$DESCRIPTION)
    desc <- modifyList(desc, as.list(metadata))
    pkg_desc$DESCRIPTION <- stats::setNames(as.character(desc), names(desc))
    base::saveRDS(pkg_desc, binary_desc)
  }

  if (!file.exists(source_desc) && !file.exists(binary_desc)) {
    stop("No DESCRIPTION found!", call. = FALSE)
  }
}
