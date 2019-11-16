if (!require("plumber")) install.packages("plumber")
if (!require("jsonlite")) install.packages("jsonlite")
library(plumber)
library(jsonlite)

pr <- plumb("plumber-api.R")

swaggerFile <- pr$swaggerFile()
swaggerFile$info$title <- "plumberCarsService"
swaggerFile$info$description <- "Returns the probability of a vehicle being fitted with a manual transmission"
swaggerFile$info$version <- "1.0.0"
swagger <- toJSON(swaggerFile, pretty = TRUE, auto_unbox = TRUE)
cat(swagger, file = "plumber-swagger.json", append = FALSE)

pr$run(port=8000)
# http://127.0.0.1:8000/swagger.json
