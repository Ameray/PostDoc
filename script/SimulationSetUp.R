#### Clear the environment
rm(list = ls())

# Define the directory where to run simulations
base_dir <- "D:/Post_doc/test"
setwd(base_dir)

# Create a working directory for today's date
today_dir <- paste(getwd(), Sys.Date(), sep = "/")
dir.create(today_dir)
setwd(today_dir)

### Input path (LANDIS input in your laptop)
inputDir <- "D:/Post_doc/Landis_inputs"

### Load required libraries
library(raster)
library(parallel)
library(doSNOW)
library(dplyr)
library(stringr)

### Define simulation parameters
simDuration <- 100
scenariosDesign <- list(area = c("coteNord"),
                        scenario = c("baseline", "RCP26", "RCP45", "RCP85"),
                        mgmt = list("coteNord" = c("1","2","3","4")),
                        fire = TRUE,
                        BDA = TRUE,
                        wind = TRUE,
                        harvest = TRUE,
                        rep = 1)

simInfo <- expand.grid(
  areaName = names(scenariosDesign$mgmt),
  scenario = scenariosDesign$scenario,
  mgmt = unlist(scenariosDesign$mgmt),
  fire = scenariosDesign$fire,
  BDA = scenariosDesign$BDA,
  wind = scenariosDesign$wind,
  harvest = scenariosDesign$harvest,
  replicate = seq_len(scenariosDesign$rep)
) %>%
  arrange(replicate)

# Set up parallel processing
cores_to_use <- floor(detectCores() * 0.5)
cl <- makeCluster(cores_to_use, outfile = "")
registerDoSNOW(cl)

# Add simulation IDs and write to CSV
simInfo$simID <- sprintf("%0*d", nchar(nrow(simInfo)), 1:nrow(simInfo))
write.csv(simInfo, "simInfo.csv", row.names = FALSE)

foreach(i = 1:nrow(simInfo)) %dopar% {
  require(raster)
  
  # Extract details for this simulation iteration
  simID <- as.character(simInfo[i, "simID"])
  areaName <- as.character(simInfo[i, "areaName"])
  scenario <- as.character(simInfo[i, "scenario"])
  mgmt <- as.character(simInfo[i, "mgmt"])
  replicate <- as.character(simInfo[i, "replicate"])
  
  # Explicitly define disturbance conditions
  harvest <- simInfo[i, "harvest"]
  fire <- simInfo[i, "fire"]
  wind <- simInfo[i, "wind"]
  BDA <- simInfo[i, "BDA"]
  
  dir.create(simID)
  
  # Copying initial communities and landtype files
  file.copy(paste0(inputDir, "/initial-communities_", areaName, ".tif"),
            paste0(simID, "/initial-communities.tif"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/landtypes_", areaName, ".tif"),
            paste0(simID, "/landtypes.tif"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/initial-communities_", areaName, ".txt"),
            paste0(simID, "/initial-communities.txt"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/landtypes_", areaName, ".txt"),
            paste0(simID, "/landtypes.txt"), overwrite = TRUE)
  
  # Succession and climate input files
  file.copy(paste0(inputDir, "/forCS-input_", areaName, "_", scenario, ".txt"),
            paste0(simID, "/forCS-input.txt"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/forCS-climate_", areaName, "_", scenario, ".txt"),
            paste0(simID, "/forCS-climate.txt"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/forCS-DM_", areaName, "_", scenario, ".txt"),
            paste0(simID, "/forCS-DM.txt"), overwrite = TRUE)
  
  # disturbances
  if (harvest) {
    file.copy(paste0(inputDir, "/stand-map_", areaName, ".tif"),
              paste0(simID, "/stand-map.tif"), overwrite = TRUE)
    file.copy(paste0(inputDir, "/mgmt-areas_", areaName, ".tif"),
              paste0(simID, "/mgmt-areas.tif"), overwrite = TRUE)
    file.copy(paste0(inputDir, "/biomass-harvest_", areaName, "_", mgmt, ".txt"),
              paste0(simID, "/biomass-harvest.txt"), overwrite = TRUE)
  }
  
  if (wind) {
    file.copy(paste0(inputDir, "/base-wind_", areaName, ".txt"),
              paste0(simID, "/base-wind.txt"), overwrite = TRUE)
  }
  
  if (fire) {
    file.copy(paste0(inputDir, "/base-fire_", areaName, "_", scenario, ".txt"),
              paste0(simID, "/base-fire.txt"), overwrite = TRUE)
    if (scenario != "baseline") {
      for (y in c(0, 30, 60)) {
        file.copy(paste0(inputDir, "/fire-regions_", areaName, "_", y, ".tif"),
                  paste0(simID, "/fire-regions_", y, ".tif"), overwrite = TRUE)
      }
    } else {
      file.copy(paste0(inputDir, "/fire-regions_", areaName, "_0.tif"),
                paste0(simID, "/fire-regions_0.tif"), overwrite = TRUE)
    }
  }
  
  if (BDA) {
    file.copy(paste0(inputDir, "/base-bda.txt"), paste0(simID, "/base-bda.txt"), overwrite = TRUE)
    for (k in 1:3) {
      file.copy(paste0(inputDir, "/base-BDA_budworm-", k, ".txt"),
                paste0(simID, "/base-BDA_budworm-", k, ".txt"), overwrite = TRUE)
    }
  }
  
  # Other required files
  file.copy(paste0(inputDir, "/output-cohort-statistics.txt"),
            paste0(simID, "/output-cohort-statistics.txt"), overwrite = TRUE)
  file.copy(paste0(inputDir, "/outbiomass.txt"),
            paste0(simID, "/outbiomass.txt"), overwrite = TRUE)
  ### species.txt
  file.copy(paste0(inputDir, "/species_",
                   areaName, ".txt"),
            paste0(simID, "/species.txt"),
            overwrite = T)
  # Scenario setup and documentation
  x <- readLines(paste0(inputDir, "/scenario.txt"))
  x <- gsub("Duration\\s\\d+", paste0("Duration ", simDuration), x)
  
  writeLines(x, paste0(simID, "/scenario.txt"))
  write.table(t(simInfo[i,]), file = paste0(simID, "/README.txt"), quote = FALSE, col.names = FALSE)
}


# Clean up cluster
stopCluster(cl)

