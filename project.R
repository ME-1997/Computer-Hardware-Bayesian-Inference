
#https://archive.ics.uci.edu/ml/datasets/Computer+Hardware

#Read data
dat = read.csv(file="E:/Bayesian models course/machine.csv", header=TRUE)
head(dat)

#Rename columns
names(dat)[names(dat) == "adviser"] <- "vendor_name"
names(dat)[names(dat) == "X32.60"] <- "model_name"
names(dat)[names(dat) == "X125"] <- "MYCT"
names(dat)[names(dat) == "X256"] <- "MMIN"
names(dat)[names(dat) == "X6000"] <- "MMAX"
names(dat)[names(dat) == "X256.1"] <- "CACH"
names(dat)[names(dat) == "X16"] <- "CHMIN"
names(dat)[names(dat) == "X128"] <- "CHMAX"
names(dat)[names(dat) == "X198"] <- "pub_perf"
names(dat)[names(dat) == "X199"] <- "pred_perf_article"

#check for NA
any(is.na(dat))




dat$vendor_idx=as.factor(dat$vendor_name)
dat$vendor_idx=as.integer(dat$vendor_idx)
str(dat)
library("rjags")


#create model 1
mod_str = " model {
  for (i in 1:length(pub_perf)) {
    pub_perf[i] ~ dpois(lam[i])
    log(lam[i]) = alpha[vendor_idx[i]] + b[1,vendor_idx[i]]*MYCT[i] + b[2,vendor_idx[i]]*MMIN[i] + b[3,vendor_idx[i]]*MMAX[i] + b[4,vendor_idx[i]]*CACH[i]+ b[5,vendor_idx[i]]*CHMIN[i] + b[6,vendor_idx[i]]*CHMAX[i]
  }
  
  mu ~ dnorm(0.0, 1.0/1.0e6)
  prec ~ dgamma(1/2.0, 1*10.0/2.0)
  mu_2 ~ dnorm(0.0, 1.0/1.0e6)
  prec_2 ~ dgamma(1/2.0, 1*10.0/2.0)
  
  for (j in 1:max(vendor_idx)) {
    alpha[j] ~ dnorm(mu, prec)
  }
  
  for(j in 1:6){
    for(i in 1:max(vendor_idx)){      
      b[j,i] ~ dnorm(mu_2, prec_2)

    }
    }
  

  sig = sqrt( 1.0 / prec )
  
 
} "


params = c("alpha", "b","mu","sig")

data_jags=as.list(dat)

mod = jags.model(textConnection(mod_str), data=data_jags, n.chains=3)
update(mod,60e3)

mod_sim = coda.samples(model=mod,
                       variable.names=params,
                       n.iter=60e3)
mod_csim = as.mcmc(do.call(rbind, mod_sim))


#read means of obtained chains
means=colMeans(mod_csim)
means

# convergence diagnostics
par(ask=TRUE,mar = rep(2, 4))
plot(mod_sim)
plot(mod_sim_2)


dic.samples(mod,1000)


gelman.diag(mod_sim)

autocorr.diag(mod_sim)

par(ask=TRUE)
autocorr.plot(mod_sim)
effectiveSize(mod_sim)


#Prepare parametrs for perdiciton loop

actual=dat$pub_perf

len=length(actual)

X=as.matrix(sapply(dat[3:8], as.numeric))

dim(as.matrix(coeffs))

pred= rep(0,len)



#prediction loop
for (i in 1:len)
  {
    index=dat$vendor_idx[i]
    
    l=30+(index-1)*6
    m=l+5
    
    coeffs=as.matrix(c(means[l:m]))
    pred[i]=means[index] + X[i,] %*% coeffs
  }

#compute residuals
resid=actual-exp(pred)

plot(resid,xlab="data index",ylab="Residuals")


#create model 2

mod_str_2 = " model {
  for (i in 1:length(pub_perf)) {
    pub_perf[i] ~ dpois(lam[i])
    log(lam[i]) = alpha[vendor_idx[i]] + b[1]*MYCT[i] + b[2]*MMIN[i] + b[3]*MMAX[i] + b[4]*CACH[i]+ b[5]*CHMIN[i] + b[6]*CHMAX[i]
  }
  
  mu ~ dnorm(0.0, 1.0/1.0e6)
  prec ~ dgamma(1/2.0, 1*10.0/2.0)
 
  
  for (j in 1:max(vendor_idx)) {
    alpha[j] ~ dnorm(mu, prec)
  }
  
  for(j in 1:6){
    b[j] ~ dnorm(0, 1/1e6)
    }
  

  sig = sqrt( 1.0 / prec )
  
 
} "


params_2 = c("alpha", "b","mu","sig")

data_jags_2=as.list(dat)

mod_2 = jags.model(textConnection(mod_str_2), data=data_jags_2, n.chains=3)
update(mod_2,60e3)

mod_sim_2 = coda.samples(model=mod_2,
                       variable.names=params_2,
                       n.iter=60e3)
mod_csim_2 = as.mcmc(do.call(rbind, mod_sim_2))


means_2=colMeans(mod_csim_2)
plot(mod_csim_2)
actual=dat$pub_perf
len=length(actual)

X=as.matrix(sapply(dat[3:8], as.numeric))

dim(as.matrix(coeffs))
pred_2= rep(0,len)
coeffs_2=means_2[30:35]
coeffs_2
for (i in 1:len)
{
  index=dat$vendor_idx[i]
  

  pred_2[i]=means_2[index] + X[i,] %*% coeffs_2
}
resid_2=actual-exp(pred_2)


#compare model 1 and model 2 residuals
par(mfrow=c(1,2))
plot(resid,ylim = c(-100,200),ylab="Original model's resuiduals")
plot(resid_2,ylim = c(-100,200),ylab="Second model's resuiduals")



### Inference using model 1

#first inference: predict best vendors for each hardware piece

bias_terms=means[1:29]
MYCT_terms=list()
MMIN_terms=list()
MMAX_terms=list()
CACH_terms=list()
CHMIN_terms=list()
CHMAX_terms=list()

for(i in 1:29){
  MYCT_terms[i]=means[30+6*(i-1)]
  MMIN_terms[i]=means[31+6*(i-1)]
  MMAX_terms[i]=means[32+6*(i-1)]
  CACH_terms[i]=means[33+6*(i-1)]
  CHMIN_terms[i]=means[34+6*(i-1)]
  CHMAX_terms[i]=means[35+6*(i-1)]
}

max_bias=dat$vendor_name[which.max(bias_terms)]
max_MYCT=dat$vendor_name[which.max(MYCT_terms)]
max_MMIN=dat$vendor_name[which.max(MMIN_terms)]
max_MMAX=dat$vendor_name[which.max(MMAX_terms)]
max_CACH=dat$vendor_name[which.max(CACH_terms)]
max_CHMIN=dat$vendor_name[which.max(CHMIN_terms)]
max_CHMAX=dat$vendor_name[which.max(CHMAX_terms)]


max_bias=dat$vendor_name[which.max(bias_terms)]
max_MYCT=dat$vendor_name[which.max(MYCT_terms)]
max_MMIN=dat$vendor_name[which.max(MMIN_terms)]
max_MMAX=dat$vendor_name[which.max(MMAX_terms)]
max_CACH=dat$vendor_name[which.max(CACH_terms)]
max_CHMIN=dat$vendor_name[which.max(CHMIN_terms)]
max_CHMAX=dat$vendor_name[which.max(CHMAX_terms)]

max_list=c(max_bias,max_MYCT,max_MMIN,max_MMAX,max_CACH,max_CHMIN,max_CHMAX)
max_list


#second inference: predict the most effective hardware piece

#Re-create model 1 again using normalized data (for fair comparison)
library("clusterSim")
norm_data=dat
norm_data[3:8]=data.Normalization(x = dat[3:8],type = "n1",normalization="column")

data_jags_norm=as.list(norm_data)

mod_norm = jags.model(textConnection(mod_str), data=data_jags_norm, n.chains=3)
update(mod_norm,60e3)

mod_sim_norm = coda.samples(model=mod_norm,
                            variable.names=params,
                            n.iter=60e3)
mod_csim_norm = as.mcmc(do.call(rbind, mod_sim_norm))

means_norm=colMeans(mod_csim_norm)
means_norm
max_comp=rep(0,29)
for(i in 1:29){
  l=30+(i-1)*6
  m=l+5
  
  coeffs=as.matrix(c(means_norm[l:m]))
  idx=which.max(coeffs)
  max_comp[i]=colnames(norm_data)[2+idx]
}
max_comp
sort(table(max_comp),decreasing=TRUE)

