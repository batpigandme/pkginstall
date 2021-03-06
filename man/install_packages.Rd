% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/install.R
\name{install_packages}
\alias{install_packages}
\title{Install multiple local packages}
\usage{
install_packages(filenames, lib = .libPaths()[[1L]],
  plan = get_install_plan(filenames, lib), metadata = NULL,
  vignettes = TRUE, num_workers = 1)
}
\arguments{
\item{filenames}{filenames of packages to install. Can be source
directories, source tarballs or binary packages.}

\item{lib}{library to install packages into}

\item{plan}{The installation plan from \code{pkgdepends::remote}}

\item{metadata}{for internal use only}

\item{vignettes}{whether to (re)build the vignettes of the packages}

\item{num_workers}{Number of parallel workers to use}
}
\description{
Install multiple local packages
}
