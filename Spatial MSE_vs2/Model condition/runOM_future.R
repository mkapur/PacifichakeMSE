### Run the OM in X amount of years 

direc <- "~/GitHub/PacifichakeMSE/Spatial MSE_vs2/Model condition/"
setwd(direc)
###### Initialize the operating model ###### 
library(TMB)
library(dplyr)
library(reshape2)
library(ggplot2)
library(scales)
library(gridExtra)

plot.figures = FALSE # Set true for printing to file 
# Run the simulation model
source('run_agebased_model_true_Catch.R')
source('ylimits.R')
source('plotUncertainty.R')
source('getUncertainty.R')
source('getSelec.R')
source('load_data_seasons_future.R')
source('create_TMB_data.R')
source('getRefpoint_biomass.R')
source('Check_Identifiable_vs2.R')
assessment <- read.csv('asssessment_MLE.csv')
assessment <- assessment[assessment$year > 1965 &assessment$year < 2018 ,]
Catch.obs <- read.csv('hake_totcatch.csv')

nruns <- 1000

seedz <- floor(runif(n = nruns,min = 1, max = 1e6))  # Random of a random 
yr.future <- 50
df <- load_data_seasons_future(yr.future)

df$Catch <- Catch.obs$Fishery
Catch.future <- c(df$Catch, rep(206507.8, yr.future))
df$Catch <- Catch.future

sim.data <- run.agebased.true.catch(df,seed =  2)
SSB0 <- sum(sim.data$SSB_0)

plot(sim.data$SSB[,2]/sim.data$SSB0[2])
lines(assessment$SSB)

SSB.save <- matrix(NA, df$nyear, nruns)
survey.save <- matrix(NA, df$nyear, nruns)
R.save <- matrix(NA, df$nyear, nruns)
Catch.save <- matrix(NA,df$nyear,nruns)
run.true <- matrix(1, nruns)


start.time <- Sys.time()

for(i in 1:nruns){
  set.seed(seedz[i])
  
  df <- load_data_seasons_future(yr.future)
  df$Catch <- Catch.future
  
  sim.data <- try(run.agebased.true.catch(df,seed =  seedz[i]), silent = TRUE)
  
  if(is.list(sim.data)){
  SSB.save[,i] <- rowSums(sim.data$SSB)
  R.save[,i] <- sim.data$N.save[1,]
  survey.save[,i] <- sim.data$survey
  Catch.save[,i] <- sim.data$Catch
  rm(sim.data)
  }else{
  run.true[i] <- 0  
  }
}

end.time <- Sys.time()
time.taken <- end.time - start.time
print(time.taken)
print(paste('Fraction of successful runs = ',sum(run.true)/nruns))

SSB.save <- SSB.save[,which(run.true == 1)]
R.save <- R.save[,which(run.true == 1)]
survey.save <- survey.save[,which(run.true == 1)]

SSB <- as.data.frame(t(apply(SSB.save,1,quantile, probs = c(0.5,0.95,0.75,0.25,0.05), names = F)))
SSB <- SSB/SSB0
names(SSB) <- c('p50','p95','p75','p25','p5')
SSB$year <- df$years



p1 <- ggplot(SSB, aes(x = year, y = p50))+
  theme_classic()+geom_point(size = 1.5)+
  geom_ribbon(aes(ymin = p5,ymax = p95), fill = alpha('gray',alpha = 0.5), linetype = 0)+
  geom_ribbon(aes(ymin = p25,ymax = p75), fill = alpha('gray',alpha = 0.8), linetype = 0)+  geom_line(size = 1.5)+
  scale_y_continuous(name = 'SSB/SSB_0')+geom_hline(aes(yintercept = 0.4),linetype =2, col = 'green')+
  geom_hline(aes(yintercept = 0.1),linetype =2, col = 'red')+
  geom_text(aes(x = 1965, y = 1.9, label = 'a'))

p1

R <- as.data.frame(t(apply(R.save,1,quantile, probs = c(0.5,0.95,0.75,0.25,0.05), names = F)))
R <- R*1e-6
names(R) <- c('p50','p95','p75','p25','p5')
R$year <- df$years



p2 <- ggplot(R, aes(x = year, y = p50))+
  theme_classic()+geom_point(size = 1.5)+
  geom_ribbon(aes(ymin = p5,ymax = p95), fill = alpha('gray',alpha = 0.5), linetype = 0)+
  geom_ribbon(aes(ymin = p25,ymax = p75), fill = alpha('gray',alpha = 0.8), linetype = 0)+  geom_line(size = 1.5)+
  scale_y_continuous(name = 'million recruits')+
  geom_text(aes(x = 1965, y = 18, label = 'b'))

p2

survey <- as.data.frame(t(apply(survey.save,1,quantile, probs = c(0.5,0.95,0.75,0.25,0.05), names = F)))
survey <- survey*1e-6
names(survey) <- c('p50','p95','p75','p25','p5')
survey$year <- df$years

survey <- survey[df$flag_survey ==1,]

p3 <- ggplot(survey, aes(x = year, y = p50))+
  theme_classic()+geom_point(size = 1.5)+
  geom_ribbon(aes(ymin = p5,ymax = p95), fill = alpha('gray',alpha = 0.5), linetype = 0)+
  geom_ribbon(aes(ymin = p25,ymax = p75), fill = alpha('gray',alpha = 0.8), linetype = 0)+  geom_line(size = 1.5)+
  scale_y_continuous(name = 'survey (million tonnes)')+
  geom_text(aes(x = 1996, y = 8.5, label = 'c'))

p3


gs <- list(p1,p2,p3)
ls.mat <- rbind(c(1,1),c(2,3))

# cairo_pdf('OM_future.pdf', width = 16, height = 12)
# png('OM_future.png', width = 16, height = 12, unit = 'cm', res = 600)



grid.arrange(p1,                         # First row with one plot spaning over 2 columns
             arrangeGrob(p2, p3, ncol = 2), # Second row with 2 plots in 2 different columns
             nrow = 2)
# dev.off()
