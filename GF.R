
library(data.table)
library(corrplot)
file <- dir("./",pattern="*snp.forR")
snp <- data.frame(fread(file), row.names=1)

library(raster)
library(rgdal)
clim.list <- dir("/home/gabnoc/projects/def-yeaman/gabnoc/GF/climate_data/", full.names=T, pattern='.tif')  #makes list of file paths for each layer
clim.layer <-  stack(clim.list)  #stacks the layers into a single object

v <- rownames(snp)
lat <- sapply(strsplit(v, "_"), "[", 1)
long <- sapply(strsplit(v, "_"), "[", 2)




sample.coord <- cbind(as.numeric(long),as.numeric(lat))
colnames(sample.coord) <- c("Long","Lat")
sample.coord <- as.data.frame(sample.coord)
extent <- c(min(sample.coord$Long) - 2.5, max(sample.coord$Long) + 2.5 ,min(sample.coord$Lat) - 2.5 ,max(sample.coord$Lat) + 2.5)
clim.layer.crop <- crop(clim.layer, extent)

pdf("clim.layer.BandA.pdf")
plot(clim.layer,1,nc =1)
plot(clim.layer.crop,1,nc =1)
dev.off()


crs.wgs <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"  #defines the spatial projection system that the points are in (usually WGS84)
sample.coord.sp <- SpatialPointsDataFrame(sample.coord[,c('Long','Lat')], proj4string=CRS(crs.wgs), data=sample.coord)

clim.points <- extract(clim.layer, sample.coord.sp)  #extracts the data for each point (projection of climate layer and coordinates must match)


cor_matrix <- cor(clim.points)

pdf("var_corr.pdf")
corrplot::corrplot(
  cor_matrix,
  order = "original",
  type = "upper", diag = T,
  tl.cex = 0.4,
  tl.srt=45, addCoef.col = "darkgray", addCoefasPercent = T
  )
dev.off()

### Remove correlated variables
# cor_matrix_rm <- cor_matrix                  # Modify correlation matrix
# cor_matrix_rm[upper.tri(cor_matrix_rm)] <- 0
# diag(cor_matrix_rm) <- 0
# cor_matrix_rm
#
# data_new <- clim.points[ , !apply(cor_matrix_rm,    # Remove highly correlated variables
#                            2,
#                            function(x) any(x > 0.7))]
# head(data_new)                               # Print updated data frame
#
# clim.points <- data_new

clim.points <- cbind(sample.coord, clim.points)  #combines the sample coordinates with the climate data points
write.table(clim.points, "clim.points", sep="\t", quote=F, row.names=F)  #save the table for later use
clim.points

# If we want PCNM vars rather than Long and Lat
# library(vegan)
# coord <- clim.points[,c("Long","Lat")]
# pcnm <- pcnm(dist(coord))  #this generates the PCNMs, you could stop here if you want all of them
# keep <- round(length(which(pcnm$value > 0))/2)
# pcnm.keep <- scores(pcnm)[,1:keep]  #keep half of positive ones as suggested by some authors
# pcnm.keep
#
#
#
# library(gradientForest)
# env.gf <- cbind(clim.points[,11:ncol(clim.points)], pcnm.keep)


library(gradientForest)
coord <- clim.points[,c("Long","Lat")]
env.gf <- cbind(clim.points[,3:ncol(clim.points)], coord)

maxLevel <- log2(0.368*nrow(env.gf)/2)
gf <- gradientForest(cbind(env.gf, snp), predictor.vars=colnames(env.gf), response.vars=colnames(snp), ntree=2000, maxLevel=maxLevel, trace=T, corr.threshold=0.50)


gf_result <- as.data.frame(gf$result)
write.table(gf_result, file = "gf_result.txt", sep = "\t", row.names = TRUE, quote = FALSE)

gf_imp <- as.data.frame(gf$overall.imp)
write.table(gf_imp, file = "gf_imp.txt", sep = "\t", row.names = TRUE, quote = FALSE)

gf_imp2 <- as.data.frame(gf$overall.imp2)
write.table(gf_imp2, file = "gf_imp2.txt", sep = "\t", row.names = TRUE, quote = FALSE)

gf_imp_rsq <- as.data.frame(gf$imp.rsq)
write.table(gf_imp_rsq, file = "gf_imp_rsq.txt", sep = "\t", row.names = TRUE, quote = FALSE)

gf_res <- as.data.frame(gf$res)
write.table(gf_res, file = "gf_res.txt", sep = "\t", row.names = FALSE, quote = FALSE)

gf_res_u <- as.data.frame(gf$res.u)
write.table(gf_res_u, file = "gf_res_u.txt", sep = "\t", row.names = FALSE, quote = FALSE)




by.importance <- names(importance(gf))
pdf("GF_VariableImportance.pdf")
plot(gf, plot.type = "O")
dev.off()

#pdf("split_denisty_plot.pdf")
#par(mgp = c(2, 0.75, 0))
#plot(gf, plot.type = "S", imp.vars = by.importance,leg.posn = "topright", cex.legend = 0.4, cex.axis = 0.6,cex.lab = 0.7, line.ylab = 0.9, par.args = list(mgp = c(1.5,0.5, 0), mar = c(3.1, 1.5, 0.1, 1)))
#dev.off()

pdf("GF_TurnoverFunctions.pdf")
plot(gf, plot.type = "C", imp.vars = by.importance, show.species = F, common.scale = T, cex.axis = 1, cex.lab = 1.2, line.ylab = 1, par.args = list(mgp = c(1.5, 0.5, 0), mar = c(2.5, 2, 2, 2), omi = c(0.2, 0.3, 0.2, 0.4)))
dev.off()

pdf("r2_fit_SNPs.pdf")
plot(gf, plot.type = "P", show.names = F, horizontal = F, cex.axis = 1, cex.labels = 0.7, line = 2.5)
dev.off()

# pdf("GF_TurnoverFunctions_bySNP.pdf")
# y_range <- range(gf$Y, na.rm = TRUE)
# plot(gf, plot.type = "C", imp.vars = by.importance, show.overall = F, legend = T, leg.posn = "topleft", leg.nspecies = 5, cex.lab = 0.7, cex.legend = 0.4, cex.axis = 0.6, line.ylab = 0.9, par.args = list(mgp = c(1.5, 0.5, 0), mar = c(2.5, 1, 0.1, 0.5), omi = c(0, 0.3, 0, 0)), ylim = y_range)
#
# dev.off()

#pdf("GF_TurnoverFunctions_bySNP.pdf")
#plot(gf, plot.type = "C", imp.vars = by.importance, show.overall = F, legend = T, leg.posn = "topleft", leg.nspecies = 5, cex.lab = 0.7, cex.legend = 0.4, cex.axis = 0.6, line.ylab = 0.9, par.args = list(mgp = c(1.5, 0.5, 0), mar = c(2.5, 1, 0.1, 0.5), omi = c(0, 0.3, 0, 0)))
#dev.off()

clim.land <- extract(clim.layer.crop, 1:ncell(clim.layer.crop), df = TRUE)
clim.land <- na.omit(clim.land)

### Remove correlated variables ???
# col_to_keep <- colnames(data_new)
# clim.land <- clim.land[ , (names(clim.land) %in% col_to_keep)]

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
