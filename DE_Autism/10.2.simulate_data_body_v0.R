#this code used for the simulation

# Simulate scRNA-seq data using splatter
# Using their default simulator for now. We can consider simulate 3000 genes in 40 individuals, with 20 cases vs. 20 controls. We can set DE for 300 genes in terms of mean expression difference, and another 300 genes DE in terms of variance difference. In the simulation, try to set the total read-depth across samples to be the same. 
# As an initial analysis, do not add any covariates. 
# For each gene, calculate density, and then JSD across samples, and then use PERMANOVA to calculate p-value for each gene. 
# Also calculate p-value for each gene using MAST-mixed effect model (less priority for now). 
# Collapse gene expression across cells per individual, then run DESeq2 for differential expression testing. 
# Type I error is the proportion of those 2400 equivalently expressed genes with p-value smaller than 0.05. 
# Power1, the proportion of the first 300 genest with p-value < 0.05
# Power2, the proportion of the next 300 genest with p-value < 0.05


# ##### a. Simulation Plan (method 4 was choisen)#############

# ####### method1: 1 batch, 40 groups, de.prob=rep(0.5,0.5),  "de.facScale", .25,  "de.facLoc", 1
# eg: DEseq2 methods:from https://bioconductor.github.io/BiocWorkshops/rna-seq-data-analysis-with-deseq2.html
#   library("splatter")
# params <- newSplatParams()
# params <- setParam(params, "de.facLoc", 1) 
# params <- setParam(params, "de.facScale", .25)
# params <- setParam(params, "dropout.type", "experiment")
# params <- setParam(params, "dropout.mid", 3)
# set.seed(1)
# sim <- splatSimulate(params, group.prob=c(.5,.5), method="groups")
# 
# 
# pros:
# easy to operated,have examples
# 
# cons:
# 1. no individual differences--batch effects
# 2. hard to characterize the differences.
# 
# 
# ####### method2: times simulation,each is 1 batch, 20 batch have group.prob=1(DE or DV), 20 batch have group.prob=0
# 
# pros:
# easy to operated
# 
# cons:
# can't fix the genes who's differential expressed. Need some further steps to putting them together...
# 
# 
# ####### method3: 40 batch, each has 3 group de.prob=c(0.33,0.33,0.33), 
#                       group1 change mean "de.facScale", .25,  "de.facLoc", 1
#                       group2 change variance  
#                       group3 Set default
#                       
# Then doing the DE analysis with 
# (1).mean comparison: first 20 group1 cell vs latter 20 group3 cell
# (2).mean comparison: first 20 group2 cell vs latter 20 group3 cell
# 
# 
# Based on all of those, I plan to take method 3 for the simulation.
# Something remaining:
# (1)make sure where is the influence place for "de.facScale",  "de.facLoc", what it influence on the gamma distribution mean.rate and mean.shape.
# (2)make sure the DE genes are consistence between batches in your simulation.


# ####### method4: generate 6 sets, each with 20 batch
#After carefully implement of method 3(chosen from the 1,2,3 method),we found that the parameter de.prob/de.fracLoc/de.fracScale are all applied on the place of outlier location, which means they are not able for the adjustment of the variance without non-influence on the mean.

#personally, in this situation, I would prefer to use Lun2 method, which is more straight forward.



#based on that, we plan to simulate 6 parts separately
#               case         |       Control
#MeanDE Genes                |
#VarDE  Genes                |
#NochangeGenes               |

#according to http://www.math.wm.edu/~leemis/chart/UDR/PDFs/Gammapoisson.pdf. The gamma-poission distribution will have the 
#mean= alpha*beta
#variance=alpha*beta+alpha^2*beta
#Thus we will adjust the alphaand beta to make our changes.



#However, this method doesn't work since the parameter mean.rate influence nothing in the package, so finally we plan to simulate 40 batches by the splatter, then manually modify the mean and variance different on the output count data.


# ####### method5: Using ZINB method directly ##########

##### Start simulation from here #############
# #something from the head files please uncomment the following lines to run it separately.
# file_tag=1
# sim_method="splat.org" #splat.mean or splat.var--method 5, separate the mean and variance using splat
#                         #splat.org--method 4, change the mean.shape and mean.rate originally
# 
# #r_mean/r_var should < 1+mean.shape
# r_mean=1.2  #1.2,1.5,2,4,8
# r_var=4 #2,4,6,8,10

#setwd("~/Desktop/fh/1.Testing_scRNAseq/")
#setwd("/Users/mzhang24/Desktop/fh/1.Testing_scRNAseq/")
setwd("/fh/fast/sun_w/mengqi/1.Testing_scRNAseq/")

library("splatter")
library("scater")
library("ggplot2")

nGeneMean=300
nGeneVar=300
nGeneBlank=2400
nGeneTotal=nGeneMean+nGeneVar+nGeneBlank
ncase=20
nctrl=20
ncell=100

i_mean=1:nGeneMean
i_var=(nGeneMean+1):(nGeneMean+nGeneVar)
i_blank=(nGeneMean+nGeneVar+1):nGeneTotal

i_case=1:ncase*ncell
i_ctrl=(ncase*ncell+1):((ncase+nctrl)*ncell)

##############functions#################



####this function returns the parameters for changing mean and variance of the gamma-poission distribution
#require:  r_m/r_v <1+mu/theta
calc_nb_param=function(mu,theta,r_m=1,r_v=1){
  #mu=mean
  #theta=overdispersion
  mu2=r_m*mu
  theta2=theta*r_m*r_m*mu/(mu*r_v+(r_v-r_m)*theta)
  return(c(mu2,theta2))
}

# # ############ Simulation data with Method 4###############################

if(sim_method=="splat.org"){
  
  #blank
  params_blank=newSplatParams(batchCells=rep(ncell,(ncase+nctrl)), nGenes = nGeneTotal,seed=seedtag)
  getParams(params_blank, c("nGenes", "mean.rate", "mean.shape"))
  sim_matrix=splatSimulate(params_blank)
  
  sim_matrix=counts(sim_matrix)
  
  ref_mean=apply(sim_matrix,1,mean)
  ref_matrix=matrix(rep(ref_mean,(ncase*ncell)),ncol=(ncase*ncell))
  
  sim_matrix[i_mean,i_case]=round(sim_matrix[i_mean,i_case]+ref_matrix[i_mean,i_case]*(r_mean-1))
  sim_matrix[i_var,i_case]= pmax(round(ref_matrix[i_var,i_case]+sqrt(1/r_var)*(sim_matrix[i_var,i_case]-
                                                                                 ref_matrix[i_var,i_case])),0)

  sim_matrix[1:10,1991:2010]
  sim_matrix[301:310,1991:2010]
  sim_matrix[601:610,1991:2010]
  
  pdf(paste0("../Data_PRJNA434002/10.Result/plot_sim_",sim_method,"_",file_tag,".pdf"),height = 4,width = 6)
  op=par(mfrow = c(2, 3), pty = "s")
  hist(log(apply(sim_matrix[i_blank,i_case],1,mean)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_matrix[i_mean,i_case],1,mean)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_matrix[i_var,i_case],1,mean)),col=rgb(1,0,0,0.3))
  
  hist(log(apply(sim_matrix[i_blank,i_ctrl],1,mean)))
  hist(log(apply(sim_matrix[i_mean,i_ctrl],1,mean)))
  hist(log(apply(sim_matrix[i_var,i_ctrl],1,mean)))
  
  hist(log(apply(sim_matrix[i_blank,i_case],1,var)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_matrix[i_mean,i_case],1,var)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_matrix[i_var,i_case],1,var)),col=rgb(1,0,0,0.3))
  
  hist(log(apply(sim_matrix[i_blank,i_ctrl],1,var)))
  hist(log(apply(sim_matrix[i_mean,i_ctrl],1,var)))
  hist(log(apply(sim_matrix[i_var,i_ctrl],1,var)))
  
  plot(sort(log(apply(sim_matrix[i_mean,i_ctrl],1,mean))),
       sort(log(apply(sim_matrix[i_mean,i_case],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_matrix[i_var,i_ctrl],1,mean))),
       sort(log(apply(sim_matrix[i_var,i_case],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_matrix[i_blank,i_ctrl],1,mean))),
       sort(log(apply(sim_matrix[i_blank,i_case],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  
  plot(sort(log(apply(sim_matrix[i_mean,i_ctrl],1,var))),
       sort(log(apply(sim_matrix[i_mean,i_case],1,var))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_matrix[i_var,i_ctrl],1,var))),
       sort(log(apply(sim_matrix[i_var,i_case],1,var))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_matrix[i_blank,i_ctrl],1,var))),
       sort(log(apply(sim_matrix[i_blank,i_case],1,var))))
  lines(c(-10,10),c(-10,10),col="red")

  par(op)
  dev.off()
  
  
  de.mean=c(rep(1,nGeneMean),rep(0,nGeneVar),rep(0,nGeneBlank))
  de.var=c(rep(0,nGeneMean),rep(1,nGeneVar),rep(0,nGeneBlank))
  de.blank=c(rep(0,nGeneMean),rep(0,nGeneVar),rep(1,nGeneBlank))
  
  phenotype=c(rep(1,ncase*ncell),rep(0,nctrl*ncell))
  individual=paste0("ind",c(rep(1:(ncase+nctrl),each=ncell)))
}


# ############ Simulation data with Method 5 ###############################



#generate the data by ZINB, based on given parameters...

if(sim_method=="zinb.naive"){
  input_file_tag="3k10"
  t_mean=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/mean.tsv"),stringsAsFactors = FALSE)
  t_dispersion=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/dispersion.tsv"),stringsAsFactors = FALSE,row.names = 1)
  t_dropout=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/dropout.tsv"),stringsAsFactors = FALSE,row.names = 1)
  #t_mean2=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/mean_signif4.tsv.gz"),stringsAsFactors = FALSE)
  #t_dispersion2=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/dispersion_signif4.tsv.gz"),stringsAsFactors = FALSE,row.names = 1)
  #t_dropout2=read.table(paste0("../Data_PRJNA434002/res_dca_rawM",input_file_tag,"/dropout_signif4.tsv.gz"),stringsAsFactors = FALSE,row.names = 1)
  
  
  mid_mean=apply(t_mean,1,median)
  mid_dispersion=apply(t_dispersion,1,median)
  mid_dropout=apply(t_dropout,1,median)
  log_mean_sample=(log(as.numeric(mid_mean)))
  log_disp_sample=(log(as.numeric(mid_dispersion)))
  logit_drop_sample=(log(as.numeric(mid_dropout)/(1-as.numeric(mid_dropout))))
  
  #Pram_log_mean=rnorm(nGeneMean+nGeneVar+nGeneBlank,mean = (log_mean_sample),sd=sd(log_mean_sample))
  #Pram_log_disp=rnorm(nGeneMean+nGeneVar+nGeneBlank,mean = (log_disp_sample),sd=sd(log_disp_sample))
  #Pram_logit_drop=rnorm(nGeneMean+nGeneVar+nGeneBlank,mean = (logit_drop_sample),sd=sd(logit_drop_sample))
  
  sample_data=cbind(log_mean_sample,log_disp_sample,logit_drop_sample)
  sample_mean=apply(sample_data,2,mean)
  sample_var=apply(sample_data,2,var)
  
  cov_matrix=matrix(NA,3,3)
  for(i in 1:3){
    for(j in 1:3){
      cov_matrix[i,j]=cov(sample_data[,i],sample_data[,j])
    }
  }
  
  require(MASS)
  gpar_ctrl=exp(mvrnorm(nGeneMean+nGeneVar+nGeneBlank, mu = sample_mean, Sigma = cov_matrix,empirical = TRUE))
  gpar_ctrl[,3]=gpar_ctrl[,3]/(1+gpar_ctrl[,3])
  
  gpar_case=gpar_ctrl
  
  special_index=sample.int(nGeneTotal,(nGeneMean+nGeneVar))
  mean_index=as.numeric(special_index[i_mean])
  var_index=as.numeric(special_index[i_var])
  
  r_mean2=r_mean
  r_var2=r_var  
  if(r_mean>1){r_mean2=1/r_mean}
  if(r_var<1){r_var2=1/r_var}
  
  gpar_case[mean_index,1:2]=t(apply(gpar_case[mean_index,1:2,drop=FALSE],1,function(x){return(calc_nb_param(x[1],x[2],r_m=r_mean2))})) #50% enlarge #50%shrinkage
  gpar_case[var_index,1:2]=t(apply(gpar_case[var_index,1:2,drop=FALSE],1,function(x){return(calc_nb_param(x[1],x[2],r_v=r_var2))})) #50% enlarge #50%shrinkage
  
  sim_case=matrix(nrow=nGeneTotal,ncol=ncase*ncell)
  sim_ctrl=matrix(nrow=nGeneTotal,ncol=nctrl*ncell)
  
  for(ig in 1:nGeneTotal){
    sim_case[ig,]=emdbook::rzinbinom(ncase*ncell,gpar_case[ig,1], gpar_case[ig,2], gpar_case[ig,3])
    sim_ctrl[ig,]=emdbook::rzinbinom(ncase*ncell,gpar_ctrl[ig,1], gpar_ctrl[ig,2], gpar_ctrl[ig,3])
  }
  
  de.mean=matrix(0,ncol=1,nrow=nGeneTotal)
  de.var=matrix(0,ncol=1,nrow=nGeneTotal)
  de.mean[mean_index]=1
  de.var[var_index]=1
  
  pdf(paste0("../Data_PRJNA434002/10.Result/plot_sim_",sim_method,"_",file_tag,".pdf"),height = 4,width = 6)
  op=par(mfrow = c(2, 3), pty = "s")
  hist(log(apply(sim_ctrl[de.mean+de.var==0,],1,mean)))
  hist(log(apply(sim_ctrl[de.mean==1,],1,mean)))
  hist(log(apply(sim_ctrl[de.var==1,],1,mean)))
  
  hist(log(apply(sim_case[de.mean+de.var==0,],1,mean)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_case[de.mean==1,],1,mean)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_case[de.var==1,],1,mean)),col=rgb(1,0,0,0.3))
  
  hist(log(apply(sim_ctrl[de.mean+de.var==0,],1,var)))
  hist(log(apply(sim_ctrl[de.mean==1,],1,var)))
  hist(log(apply(sim_ctrl[de.var==1,],1,var)))
  
  hist(log(apply(sim_case[de.mean+de.var==0,],1,var)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_case[de.mean==1,],1,var)),col=rgb(1,0,0,0.3))
  hist(log(apply(sim_case[de.var==1,],1,var)),col=rgb(1,0,0,0.3))
  
  
  plot(sort(log(apply(sim_ctrl[de.mean+de.var==0,],1,mean))),sort(log(apply(sim_case[de.mean+de.var==0,],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_ctrl[de.mean==1,],1,mean))),sort(log(apply(sim_case[de.mean==1,],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_ctrl[de.var==1,],1,mean))),sort(log(apply(sim_case[de.var==1,],1,mean))))
  lines(c(-10,10),c(-10,10),col="red")
  
  
  plot(sort(log(apply(sim_ctrl[de.mean+de.var==0,],1,var))),sort(log(apply(sim_case[de.mean+de.var==0,],1,var))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_ctrl[de.mean==1,],1,var))),sort(log(apply(sim_case[de.mean==1,],1,var))))
  lines(c(-10,10),c(-10,10),col="red")
  plot(sort(log(apply(sim_ctrl[de.var==1,],1,var))),sort(log(apply(sim_case[de.var==1,],1,var))))
  lines(c(-10,10),c(-10,10),col="red")
  
  par(op)
  dev.off()
  sim_matrix=cbind(sim_case,sim_ctrl)
  
  phenotype=c(rep(1,ncase*ncell),rep(0,nctrl*ncell))
  individual=paste0("ind",c(rep(1:(ncase+nctrl),each=ncell)))
}

####################### Count info for matrix ###########
cell_id=paste0("cell",1:ncol(sim_matrix))
gene_id=paste0("gene",1:nrow(sim_matrix))

rownames(sim_matrix)=gene_id
colnames(sim_matrix)=cell_id

####################### Cell info for meta ###########

cellsum=apply(sim_matrix,2,sum)
genesum=apply(sim_matrix,1,sum)
CDR=apply(sim_matrix>0,2,sum)/nrow(sim_matrix)
meta=data.frame(cbind(cell_id,individual,phenotype,cellsum,CDR))


######################Some basic stat (OPTIONS) ##############################


#individual level info
cur_individual=unique(meta$individual)
cell_num=matrix(ncol=1,nrow=length(cur_individual))
rownames(cell_num)=cur_individual
colnames(cell_num)="cell_num"
read_depth=matrix(ncol=1,nrow=length(cur_individual))
rownames(read_depth)=cur_individual
colnames(read_depth)="read_depth"
phenotype_ind=matrix(ncol=1,nrow=length(cur_individual))
rownames(phenotype_ind)=cur_individual
colnames(phenotype_ind)="phenotype"

zero_rate_ind=matrix(nrow=nrow(sim_matrix),ncol=length(cur_individual))
rownames(zero_rate_ind)=rownames(sim_matrix)
colnames(zero_rate_ind)=cur_individual
sim_matrix_bulk=matrix(nrow=nrow(sim_matrix),ncol=length(cur_individual))
rownames(sim_matrix_bulk)=rownames(sim_matrix)
colnames(sim_matrix_bulk)=cur_individual

for(i_ind in 1:length(cur_individual)){
  cur_ind=cur_individual[i_ind]
  #fit org
  cur_ind_m=sim_matrix[,meta$individual==cur_ind]
  cell_num[i_ind]=ncol(cur_ind_m)
  read_depth[i_ind]=sum(cur_ind_m,na.rm = TRUE)/cell_num[i_ind]*1000
  phenotype_ind[i_ind]=meta$phenotype[meta$individual==cur_ind][1]
  
  zero_rate_ind[,i_ind]=apply(cur_ind_m==0,1,function(x){return(sum(x,na.rm = TRUE))})/cell_num[i_ind]
  sim_matrix_bulk[,i_ind]=apply(cur_ind_m,1,function(x){return(sum(x,na.rm = TRUE))})
}

hist(read_depth)



#almost no need to adjust library size.
tryCatch(saveRDS(de.mean,paste0("../Data_PRJNA434002/10.Result/sim_de.mean_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds")), error = function(e) {NA} )
tryCatch(saveRDS(de.var,paste0("../Data_PRJNA434002/10.Result/sim_de.var_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds")), error = function(e) {NA} )

saveRDS(read_depth,paste0("../Data_PRJNA434002/10.Result/sim_ind_readdepth_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds"))
saveRDS(zero_rate_ind,paste0("../Data_PRJNA434002/10.Result/sim_ind_zero_rate_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds"))


saveRDS(sim_matrix,paste0("../Data_PRJNA434002/10.Result/sim_matrix_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds"))
saveRDS(meta,paste0("../Data_PRJNA434002/10.Result/sim_meta_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds"))
saveRDS(sim_matrix_bulk,paste0("../Data_PRJNA434002/10.Result/sim_matrix_bulk_",sim_method,"_",r_mean,"_",r_var,"_",file_tag,".rds"))




