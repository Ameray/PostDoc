# step 2
# Clear workspace
######
rm(list = ls())

# Set working directory
wwd <- "D:/Post_doc/test/2025-02-09/"
setwd(wwd)
#setwd(wwd)
wwd <- getwd()
wwd
simInfo <- read.csv("simInfo.csv", colClasses = c(simID = "character"))
simDir <- simInfo$simID
simDir
# Load required libraries
require(parallel)
require(doSNOW)

# Define the number of simultaneous processes and batch size
maxProcesses <-2 # Run up to 4 simulations per batch depends on your laptop capacity
numSimulations <- length(simDir)
numBatches <- ceiling(numSimulations / maxProcesses)
numBatches
# Loop through batches
for (batch in 1:numBatches) {
  # Calculate start and end indices for the current batch
  startIndex <- (batch - 1) * maxProcesses + 1
  endIndex <- min(batch * maxProcesses, numSimulations)
  
  # Get the subset of simulations for this batch
  currentSimulations <- simDir[startIndex:endIndex]
  
  # Create a cluster for the current batch
  cl <- makeCluster(min(maxProcesses, length(currentSimulations)), outfile = "")
  registerDoSNOW(cl)
  
  # Run simulations in parallel for the current batch
  foreach(i = startIndex:endIndex, .packages = c("parallel")) %dopar% {
    # Set working directory for the simulation
    setwd(paste(wwd, simInfo[i, "simID"], sep = "/"))
    
    # Read the existing README file and update it
    readmeOld <- readLines("README.txt")
    readmeOld <- readmeOld[1:which(grepl(tail(colnames(simInfo), 1), readmeOld))]
    x <- as.character(shell("landis-ii-extensions.cmd list", intern = TRUE))
    
    # Append details to the README file
    sink(file = "README.txt")
    for (l in seq_along(readmeOld)) {
      cat(readmeOld[l])
      cat("\n")
    }
    sink()
    
    sink(file = "README.txt", append = TRUE)
    cat("\n")
    cat("#######################################################################\n")
    cat("########### Installed LANDIS-II extensions\n")
    cat("#######################################################################\n")
    for (l in seq_along(x)) {
      cat(x[l])
      cat("\n")
    }
    cat("\n")
    cat("#######################################################################\n")
    cat("########### System Info\n")
    cat(write.table(as.data.frame(Sys.info()),
                    quote = FALSE, col.names = FALSE))
    sink()
    
    # Run the simulation
    shell("landis-ii-7.cmd scenario.txt", wait = TRUE)
  }
  
  # Stop the cluster after the batch completes
  stopCluster(cl)
  
  # Print batch completion message
  cat(sprintf("Batch %d/%d completed.\n", batch, numBatches))
  
  # Perform garbage collection to free up memory
  gc()
}

