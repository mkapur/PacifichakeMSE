###### Run the HAKE MSE ####### 
run_multiple_MSEs <- function(simyears = NULL,seed = 123){

if(is.null(simyears)){
  print('Number of years to simulate not specified. Simulating 30 years into the future')
  simyears <- 30
}
  
df <- load_data_seasons()

df$Catch <- Catch.obs$Fishery
time <- 1
yrinit <- df$nyear
### Run the OM and the EM for x number of years in the MSE 
### Set targets for harvesting etc 
#
# df$parms$Rin <- df$parms$Rin*0
# df$F0 <- 0*df$F0

# simyears <- 5 # Project 25 years into the future (2048 that year)
year.future <- c(df$years,(df$years[length(df$years)]+1):(df$years[length(df$years)]+simyears))
N0 <- NA
sim.data <- run.agebased.true.catch(df,seed)
simdata0 <- sim.data # The other one is gonna get overwritten. 

# 
# save(sim.data,file = 'simulated_space_OM.Rdata')
# save(df,file = 'sim_data_parms.Rdata')

F40.save<- array(NA,simyears)

# Save some stuff
SSB.save <- list()
R.save <- list()
Catch.save <- list()
S.year.future <- seq(2019,2019+simyears, by = 2)
# Save som OM stuff 
# SSB.save.om <- array(NA, df$nyear+simyears)
# R.save.om <- array(NA, df$nyear+simyears)
# Catch.save.om <- array(NA, df$nyear+simyears)

# Save the estimated parameters from the EM (exclude time varying) 
parms.save <- array(NA, dim = c(simyears, 4))

# Before the MSE starts 
# SSB.save.om[1:df$tEnd] <- sim.data$SSB
# R.save.om[1:df$nyear] <- sim.data$N.save[1,]
# Catch.save.om[1:df$nyear] <- sim.data$Catch
F0.save <- df$fmort
years <- df$years
model.save <- list()

## 

SSB.test.om <- list() # Test if SSB is the same in the OM
start.time <- Sys.time()

for (time in 1:simyears){
  
  year <- yrinit+(time-1)
 #print(year.future[year])
  
  
  if (time > 1){
    
    if(sum(year.future[year] == S.year.future)>0){
      df$flag_survey <- c(df$flag_survey,1)
      df$survey_x <- c(df$survey_x,2)
      # df$ss_catch <- c(df$ss_catch,ceiling(mean(df$ss_catch[df$ss_catch > 0])))
      df$ss_survey <- c(df$ss_survey,ceiling(mean(df$ss_survey[df$ss_survey > 0])))
      df$survey_err <- c(df$survey_err,mean(df$survey_err[df$survey_err < 1]))
      
    }else{
      df$flag_survey <- c(df$flag_survey,-1)
      df$survey_x <- c(df$survey_x,-2)
      df$ss_survey <- c(df$ss_survey,-1)
      df$survey_err <- c(df$survey_err,1)
    }
    
    df$ss_catch <- c(df$ss_catch,ceiling(mean(df$ss_catch[df$ss_catch > 0])))
    df$flag_catch <- c(df$flag_catch,1)
    df$years <- year.future[1:year]
    df$nyear <- length(df$years)
    #df$tEnd <- df$tEnd+1 # Just run one more year in subsequent runs
    df$wage_catch <- df.new$wage_catch
    df$wage_survey <- df.new$wage_survey
    df$wage_mid <- df.new$wage_mid
    df$wage_ssb <- df.new$wage_ssb
    df$Catch <- c(df$Catch, Fnew[[1]])
    df$b <- c(df$b,0.87)
    Rdevs <- rnorm(n = 1,mean = 0, sd = exp(df$logSDR))
    #Rdevs <- rep(0, yr.future)
    df$parms$Rin <- c(df$parms$Rin,Rdevs)
    #df$years <- c(df$years,df$years[length(df$years)]+1)
    
    
    sim.data <- run.agebased.true.catch(df, seed)
    
 
    
  }
  
  PSEL <- matrix(0,5, length(1991:years[length(years)]))
  initN <- rep(0,df$nage-1)
  F0 <- rep(0.001, df$nyear)
  Rdev <- rep(0, df$nyear)
  
  parms <- list( # Just start all the simluations with the same initial conditions 
    logRinit = 15,
    logh = log(0.5),
    logMinit = log(0.3),
    logSDsurv = log(0.3),
    logphi_catch = log(0.8276),
    logphi_survey = log(11.33),
    # Selectivity parameters 
    psel_fish = c(2.486490, 0.928255,0.392144,0.214365,0.475473),
    psel_surv = c(0.568618,-0.216172,0.305286 ,0.373829),
    initN = initN,
    Rin = Rdev,
    F0 = F0,
    PSEL = PSEL
  )
  
  ##  Create a data frame to send to runHakeassessment 
  
  df.new <- create_TMB_data(sim.data, df)
  
  obj <-MakeADFun(df.new,parms,DLL="runHakeassessment", silent = TRUE) # Run the assessment 
  
  reps <- obj$report()
  
  lower <- obj$par-Inf
  upper <- obj$par+Inf
  
  lower[names(lower) == 'F0'] <- 0.01
  upper <- obj$par+Inf
  upper[names(upper) == 'psel_fish' ] <- 5
  upper[names(upper) == 'PSEL'] <- 5
  upper[names(upper) == 'logh'] <- log(0.999)
  upper[names(upper) == 'F0'] <- 2
  
  
  system.time(opt<-nlminb(obj$par,obj$fn,obj$gr,lower=lower,upper=upper,
                          control = list(iter.max = 1e5, 
                                         eval.max = 1e5))) # If error one of the random effects is unused
  
  
  if(opt$convergence != 0){
    print(paste('year',df$years[length(df$years)], 'did not converge'))
    stop('Model not converged')
    xx<- Check_Identifiable_vs2(obj)
    
  }
  
  reps <- obj$report()
  
  SSB <- reps$SSB
  Fyear <- reps$Fyear
  N <- reps$N
  Catch <- reps$Catch
  R <- reps$R
  
  
  
  # #Uncertainty
  if(time == simyears){
    rep <- sdreport(obj)
    sdrep <- summary(rep)
    rep.values<-rownames(sdrep)
    nyear <- df$tEnd

    
    SSB <- data.frame(name = sdrep[rep.values == 'SSB',1])
    SSB$SE <- sdrep[rep.values == 'SSB',2]
    SSB$min <- SSB$name-2*SSB$SE
    SSB$max <- SSB$name+2*SSB$SE
    SSB$year <- df$years
  
    # p1 <- plotValues(SSB, data.frame(x=df$years,y = rowSums(sim.data$SSB)), 'SSB')
    # p1
    SSB.hes <- SSB
    SSB <- SSB$name
    
    
    
  }
 
  Nend <- N[,dim(N)[2]]
  Fnew <- getRefpoint(opt$par, df,SSB[length(SSB)], Fin=Fyear[length(Fyear)], Nend)
  #Fnew <- 0.3
  #print(paste('new quota = ',Fnew[[1]]))
  # Update the data data frame
  
  Ntmp <- sim.data$Nout
  
  
  # Save some EM stuff in the last year 
  SSB.save[[time]] <- SSB
  R.save[[time]] <- N[1,]
  F40.save[time] <- Fnew[[2]]
  Catch.save[[time]] <- Catch
  
  # And the fishing mortality
  F0.save <- Fnew
  
  #  print(year.future[year])
  #SSB.test.om[[time]] <- rowSums(sim.data$SSB)
  
  ### Include the parameters needed to calculate SSB0 
  parms.save[time, ] <- exp(opt$par)[1:4]
  
    
    
  
}

nms <- unlist(strsplit(names(opt$par), split = 'log')[1:4])[c(2,4,6,8)]
names(parms.save) <- nms
  

end.time <- Sys.time()
time.taken <- end.time - start.time
print(time.taken)


## Calculate the average age 

#dev.off()


df.ret <- list(Catch = sim.data$Catch,  # All output is from the OM 
               SSB = sim.data$SSB, 
               SSB.hes = SSB.hes,
               Survey.om = sim.data$survey,
               F0 = F0.save,
               V = sim.data$V.all[,1,],
               parms = parms.save,
               am.c = sim.data$age_catch,
               am.s = sim.data$age_comps_surv
               )

return(df.ret)
}