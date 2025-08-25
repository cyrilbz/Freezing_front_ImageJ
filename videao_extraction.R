library(Thermimage)

######################## inputs ###################

# working directory
setwd("/home/cbozonnet/Documents/image_processing/freezing_fronts/") 

# set filename as v
v<-"./video_capucine.seq"

start_frame <-1
skip_every <- 3 # important to skip images, to avoid memory overflow
output_name <- "skip2"

###################################################

# Extract camera values using Exiftool (needs to be installed)
camvals<-flirsettings(v)
w<-camvals$Info$RawThermalImageWidth
h<-camvals$Info$RawThermalImageHeight

# create lookup table
suppressWarnings(
  templookup<-raw2temp(raw=1:65536, E=camvals$Info$Emissivity, OD=camvals$Info$ObjectDistance, RTemp=camvals$Info$ReflectedApparentTemperature, ATemp=camvals$Info$AtmosphericTemperature, IRWTemp=camvals$Info$IRWindowTemperature, IRT=camvals$Info$IRWindowTransmission, RH=camvals$Info$RelativeHumidity, PR1=camvals$Info$PlanckR1,PB=camvals$Info$PlanckB,PF=camvals$Info$PlanckF,PO=camvals$Info$PlanckO,PR2=camvals$Info$PlanckR2)
)
plot(templookup, type="l", xlab="Raw Binary 16 bit Integer Value", ylab="Estimated Temperature (C)")

# get frame indices
fl<-frameLocates(v, w, h)
n.frames<-length(fl$f.start)

# extract time stamps
extract.times<-do.call("c", lapply(fl$h.start, getTimes, vidfile=v))
#data.frame(extract.times)

# find frame rate
Interval<-signif(mean(as.numeric(diff(as.POSIXct(extract.times)))),3)

# correct the interval
Interval<-Interval*skip_every

# extract the data you want (all or at a given rate or given interval)
alldata<-unlist(lapply(fl$f.start[seq(start_frame,length(fl$f.start),skip_every)], getFrames, vidfile=v, w=w, h=h))
class(alldata); length(alldata)/(w*h)

# convert these data into Temperature using lookup table
# alltemperature<-templookup[alldata]
# head(alltemperature)

# store thermal data as a matrix
alldata<-unname(matrix(alldata, nrow=w*h, byrow=FALSE))
# alltemperature<-unname(matrix(alltemperature, nrow=w*h, byrow=FALSE))
# dim(alltemperature)

# export stack to ImageJ readable format
writeFlirBin(bindata=alldata, templookup, w, h, Interval, rootname=output_name)

# in IJ -> Import as 32 bit - real !