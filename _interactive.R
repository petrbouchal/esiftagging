# script for quickly loading

source("_targets_packages.R")
source("R/utils.R")
source("R/functions.R")

library(usethis)
library(devtools)
library(targets)
library(tarchetypes)

options(scipen = 9)

ts <- as.list(targets::tar_manifest(fields = name)[["name"]])
names(ts) <- ts

cnf <- config::get(config = "default")
names(cnf) <- paste0("c_", names(cnf))
list2env(cnf, envir = .GlobalEnv)
