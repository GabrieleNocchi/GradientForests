library(data.table)

snp <- data.frame(fread("snp.forR"), row.names=1)

library(raster)
library(rgdal)
clim.list <- dir("./climate_data/", full.names=T, pattern='.tif')  #makes list of file paths for each layer
clim.layer <-  stack(clim.list)  #stacks the layers into a single object


sample.coord <-read.table("sampling_data.csv", header=F, stringsAsFactors=F, sep = ",")
colnames(sample.coord) <- c("Taxon_name","Pop_ID","Sample_name","Country","Pool_Size","Lat","Long","Alt","Author","Data_type")
sample.coord <- sample.coord[,1:10]
sample.coord


extent <- c(min(sample.coord$Long) - 3, max(sample.coord$Long) +3 ,min(sample.coord$Lat) -3 ,max(sample.coord$Lat) +3)
clim.layer.crop <- crop(clim.layer, extent)

pdf("clim.layer.BandA.pdf")
plot(clim.layer,1:6,nc =2)
plot(clim.layer, 7:12,nc =2)
plot(clim.layer, 13:18,nc =2)
plot(clim.layer, 19,nc =2)
plot(clim.layer.crop,1:6,nc =2)
plot(clim.layer.crop, 7:12,nc = 2)
plot(clim.layer.crop, 13:18, nc =2)
plot(clim.layer.crop, 19,nc =2)
dev.off()


crs.wgs <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"  #defines the spatial projection system that the points are in (usually WGS84)
sample.coord.sp <- SpatialPointsDataFrame(sample.coord[,c('Long','Lat')], proj4string=CRS(crs.wgs), data=sample.coord)

clim.points <- extract(clim.layer.crop, sample.coord.sp)  #extracts the data for each point (projection of climate layer and coordinates must match)
clim.points <- cbind(sample.coord, clim.points)  #combines the sample coordinates with the climate data points
write.table(clim.points, "clim.points", sep="\t", quote=F, row.names=F)  #save the table for later use
clim.points

library(vegan)
coord <- clim.points[,c("Long","Lat")]
pcnm <- pcnm(dist(coord))  #this generates the PCNMs, you could stop here if you want all of them
keep <- round(length(which(pcnm$value > 0))/2)
pcnm.keep <- scores(pcnm)[,1:keep]  #keep half of positive ones as suggested by some authors
pcnm.keep



library(gradientForest)
env.gf <- cbind(clim.points[,11:29], pcnm.keep)



maxLevel <- log2(0.368*nrow(env.gf)/2)
gf <- gradientForest(cbind(env.gf, snp), predictor.vars=colnames(env.gf), response.vars=colnames(snp), ntree=500, maxLevel=maxLevel, trace=T, corr.threshold=0.50)


pdf("GF_VariableImportance.pdf")
plot(gf, plot.type = "O")
dev.off()



by.importance <- names(importance(gf))

pdf("GF_TurnoverFunctions.pdf")
plot(gf, plot.type = "C", imp.vars = by.importance, show.species = F, common.scale = T, cex.axis = 1, cex.lab = 1.2, line.ylab = 1, par.args = list(mgp = c(1.5, 0.5, 0), mar = c(2.5, 2, 2, 2), omi = c(0.2, 0.3, 0.2, 0.4)))
dev.off()






clim.land <- extract(clim.layer.crop, 1:ncell(clim.layer.crop), df = TRUE)
clim.land <- na.omit(clim.land)
pred <- predict(gf, clim.land[,-1])  #note the removal of the cell ID column with [,-1])


PCs <- prcomp(pred, center=T, scale.=F)
r <- PCs$x[, 1]
g <- PCs$x[, 2]
b <- PCs$x[, 3]
r <- (r - min(r))/(max(r) - min(r)) * 255
g <- (g - min(g))/(max(g) - min(g)) * 255
b <- (b - min(b))/(max(b) - min(b)) * 255
mask<-clim.layer.crop$bio_1
mask[]<-as.numeric(mask[]>0)
rastR <- rastG <- rastB <- mask
rastR[clim.land$ID] <- r
rastG[clim.land$ID] <- g
rastB[clim.land$ID] <- b
rgb.rast <- stack(rastR, rastG, rastB)


pdf("GF_Map.pdf")
plotRGB(rgb.rast, bgalpha=0)
points(clim.points$Long, clim.points$Lat)
dev.off()