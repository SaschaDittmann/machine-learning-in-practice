# plumber.R

model <- readRDS("cars-model.rds")

#* Plot a histogram of the gross horsepower
#* @png
#* @get /plothp
function(){
  hist(mtcars$hp)
}

#* Plot a histogram of the manual transmission
#* @png
#* @get /plotam
function(){
  hist(mtcars$am)
}

#* Plot a histogram of the weight (1000 lbs)
#* @png
#* @get /plotwt
function(){
  hist(mtcars$wt)
}

#* Returns the probability whether the car has a manual transmission
#* @param hp Gross horsepower
#* @param wt Weight (1000 lbs)
#* @post /manualtransmission
function(hp, wt){
  newdata <- data.frame(hp = as.numeric(hp), wt = as.numeric(wt))
  predict(model, newdata, type = "response")
}
