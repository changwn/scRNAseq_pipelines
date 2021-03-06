#this code analysis the fit result based on the observation and permutation
set.seed(3826)
#something from the header file

#cluster_tag=1 #this tag indicate the clusters it can be choose in 1 to 17
library("moments")
setwd("~/Desktop/fh/1.Testing_scRNAseq/")
#setwd("/Users/mzhang24/Desktop/fh/1.Testing_scRNAseq/")
#setwd("/fh/fast/sun_w/mengqi/1.Testing_scRNAseq/")
file_tag="rawMnorm3k10"
raw_count_tag="3k10"
perm_num=100

for(cluster_tag in 1:17){
  print(cluster_tag)
  fit_ob=readRDS(paste0("../Data_PRJNA434002/zlm_output/zlms_",file_tag,"_",cluster_tag,"_0.rds"))$datatable
  fit_ob=fit_ob[fit_ob$contrast=="diagnosisControl",c("component","primerid","Pr(>Chisq)")]
  
  fit_perm=matrix(ncol=perm_num,nrow=nrow(fit_ob))
  for(ip in 1:perm_num){
    if(file.exists(paste0("../Data_PRJNA434002/zlm_output/zlms_",file_tag,"_",cluster_tag,"_",ip,".rds"))){
      cur_fit=readRDS(paste0("../Data_PRJNA434002/zlm_output/zlms_",file_tag,"_",cluster_tag,"_",ip,".rds"))$datatable
      cur_fit=c(cur_fit[cur_fit$contrast=="diagnosisControl","Pr(>Chisq)"])
      cur_fit=unlist(cur_fit)
      fit_perm[,ip]=cur_fit
    }
  }
  
  #restriction for our analysis on model H
  fit_perm=fit_perm[fit_ob$component=="H",]
  fit_ob=fit_ob[fit_ob$component=="H",]
  fit_ob_pval=c(fit_ob[,"Pr(>Chisq)"])
  fit_ob_pval=unlist(fit_ob_pval)
  
  #remove the NAs from genes.
  na_flag=!is.na(fit_ob_pval)
  fit_ob_pval=fit_ob_pval[na_flag]
  fit_perm=fit_perm[na_flag,]
  fit_ob=fit_ob[na_flag,]
  
  na_rate=1-sum(na_flag)/length(na_flag)
  #####1.Permutation Plot for p-values <1##################### 
  pdf(paste0("histogram_pval_celltype_",cluster_tag,".pdf"),width=6,height=6)
  for(i in sample.int(length(fit_ob_pval),50,replace=FALSE)){
    if(fit_ob_pval[i]!=1){
      hist(fit_perm[i,],breaks=20,main=paste0("p-value distribution of gene#",i,"from permutated data"))
      abline(v=fit_ob_pval[i],col="red")
    }
  }
  rawp=rowSums(fit_perm-fit_ob_pval<=0)/perm_num
  hist(rawp[rawp<1],breaks=20,main=paste0("permutation pval(pval<1),zero rate ",round(sum(rawp==1)/length(rawp),4)))
  hist(fit_perm[fit_perm<1],breaks=20,main=paste0("pval(pval<1) from permutated data,zero rate ",round(sum(fit_perm==1)/length(fit_perm),4)))
  dev.off()
  
  ##### 2.Digging out some results##############
  # 2.1. The previous part1 shows the high percentage of p-value=1 in observation.We'd like to see:
  # 2.1.1.What's these genes' original log-expression patterns?
  # 2.1.2.What's the pvalues from the permutated data associated with those genes? 
  #     Are they also all equals 1?
  
  meta=readRDS("../Data_PRJNA434002/meta10.rds")
  rawM=readRDS(paste0("../Data_PRJNA434002/rawM",raw_count_tag,".rds"))
  rawMnorm=readRDS(paste0("../Data_PRJNA434002/",file_tag,".rds"))
  rawM_index=match(rownames(rawM),rownames(rawMnorm)) #no difference between the 2 row files matching.
  
  cur_cluster=as.character(unique(meta$cluster)[cluster_tag])
  rawM=as.matrix(rawM[,meta$cluster==cur_cluster])
  meta=meta[meta$cluster==cur_cluster,]
  
  rawM=rawM[match(fit_ob$primerid, rownames(rawM)),]
  
  rawM_0zero_num=apply(rawM>0,1,function(x){return(sum(x))})
  
  table(rawM_0zero_num)[1:16]
  
  perm_pval1_rate=apply(fit_perm==1,1,function(x){return(sum(x)/length(x))})
  table(rawM_0zero_num[perm_pval1_rate==1])
  
  
  pdf(paste0("Stat_4_pval1_",cluster_tag,".pdf"),width=6,height=6)
  
  plot(rawM_0zero_num,perm_pval1_rate, cex=.2, main="relationship between non-zero count number and pval=1 rate") # less count generate the 1 pvalues.
  
  for(i in sample.int(length(fit_ob_pval),50,replace=FALSE)){
    if(perm_pval1_rate[i]==1 && rawM_0zero_num[i]>1){
      non_zero_flag=rawM[i,]>0
      hist(rawM[i,non_zero_flag],breaks=20,main=paste0("log expression of gene#",i,
                                                       ", pval ob=", round(fit_ob_pval[i],4),
                                                       ", non-zero num=",rawM_0zero_num[i]),
           sub=paste0("ind#: ",length(table(meta$individual[non_zero_flag])),
                      ", diag#: ",length(table(meta$diagnosis[non_zero_flag]))))
    }
  }
  
  rawM_allpval1=rawM[(perm_pval1_rate==1 ),]
  hist(rawM[rawM>0])
  hist(rawM_allpval1[rawM_allpval1>0],add=T,col="red")
  dev.off()
  #so here we get some conclusion that 
  #(1) the genes with high perm_pval1_rate are usually have less expression cases(i.e.<20).
  #(2) the pvalues from permutated data=1 is not due to the situlation that all expressed genes from a same individual.
  #   However, the situation is opposite, that is almost all situations are come from different individuals, while each individual only have 1 record.
  
  
  # We further cares about the distribution of the permutated p-values for each tested genes, for them we do:
  # What's these genes' original log-expression patterns?
  # KS test and skewness on them
  pdf(paste0("Stat_non-uniform_pval_vs_expression_",cluster_tag,".pdf"),width=6,height=6)
  
  op=par(mfrow=c(2,2))
  hist(rawp,breaks=30,main="perm pvalues",sub=paste0("n=",length(rawp)))
  hist(rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))],breaks=30,main="perm pvalues,rawM_0zero_num<max(20,min(rawM_0zero_num+5))",
       sub=paste0("n=",length(rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))]),", ks_pval=",
                  ks.test((1:length(rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))]))/length(rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))]),rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))],alternative = "two.sided")$p.value))
  hist(rawp[rawM_0zero_num>=20 & rawM_0zero_num<100],breaks=30,main="perm pvalues,rawM_0zero_num 20-30",
       sub=paste0("n=",length(rawp[rawM_0zero_num>=20 & rawM_0zero_num<100]),", ks_pval=",
                  ks.test((1:length(rawp[rawM_0zero_num>=20 & rawM_0zero_num<100]))/length(rawp[rawM_0zero_num>=20 & rawM_0zero_num<100]),rawp[rawM_0zero_num>=20 & rawM_0zero_num<100],alternative = "two.sided")$p.value))
  hist(rawp[rawM_0zero_num>=100],breaks=30,main="perm pvalues,rawM_0zero_num>=100",
       sub=paste0("n=",length(rawp[rawM_0zero_num>=100]),", ks_pval=",
                  ks.test((1:length(rawp[rawM_0zero_num>=100]))/length(rawp[rawM_0zero_num>=100]),rawp[rawM_0zero_num>=100],alternative = "two.sided")$p.value))
  par(op)
  hist(rawp,breaks=30,main="perm pvalues")
  hist(rawp[rawM_0zero_num<max(20,min(rawM_0zero_num+5))],breaks=30,add=T,col=rgb(1,0,0,0.3))
  hist(rawp[rawM_0zero_num>=20 & rawM_0zero_num<100],breaks=30,add=T,col=rgb(0,1,0,0.3))
  hist(rawp[rawM_0zero_num>=100],breaks=30,add=T,col=rgb(0,0,1,0.3))
  
  
  ksgreater=apply(fit_perm,1,
                  function(x){return(ks.test((1:length(x))/length(x),x,alternative = "greater")$p.value)})
  ksless=apply(fit_perm,1,
               function(x){return(ks.test((1:length(x))/length(x),x,alternative = "less")$p.value)})
  kstwoside=apply(fit_perm,1,
                  function(x){return(ks.test((1:length(x))/length(x),x,alternative = "two.sided")$p.value)})
  
  
  
  #####################KS vs expression#
  plot(rawM_0zero_num,-log10(kstwoside),cex=.2,xlab="expressed cell num",
       main=paste0("sig_KStwoside: ",round(sum(kstwoside<0.01)*100/length(kstwoside),3),"%"))
  abline(h=2,col="blue")
  plot(rawM_0zero_num,-log10(ksgreater),cex=.2,xlab="expressed cell num",
       main=paste0("sig_KSgreater: ",round(sum(ksgreater<0.01)*100/length(ksgreater),3),"%"))
  abline(h=2,col="blue")
  plot(rawM_0zero_num,-log10(ksless),cex=.2,xlab="expressed cell num",
       main=paste0("sig_KSless: ",round(sum(ksless<0.01)*100/length(ksless),3),"%"))
  abline(h=2,col="blue")
  
  op=par(mfrow=c(2,2))
  hist(rawM_0zero_num[kstwoside>0.2],breaks=30,main="expression cell num,kstwoside>0.2")
  hist(rawM_0zero_num[kstwoside<0.01],breaks=30,main="expression cell num,kstwoside<0.01")
  hist(rawM_0zero_num[ksgreater<0.01],breaks=30,main="expression cell num,ksgreater<0.01")
  hist(rawM_0zero_num[ksless<0.01],breaks=30,main="expression cell num,ksless<0.01")
  par(op)
  hist(rawM_0zero_num[kstwoside>0.2],breaks=30,main="expression cell num")
  hist(rawM_0zero_num[kstwoside<0.01],breaks=30,add=T,col=rgb(1,0,0,0.3))
  hist(rawM_0zero_num[ksgreater<0.01],breaks=30,add=T,col=rgb(0,1,0,0.3))
  hist(rawM_0zero_num[ksless<0.01],breaks=30,add=T,col=rgb(0,0,1,0.3))
  
  
  #we separate the genes who have perm_pval1_rate<0.2 into 3 categories, labeled as: 
  # ksless_sig, ksgreater_sig and ks_nonsig and we plot some features of them:
  
  kstwoside_sig=(kstwoside<0.01)
  ksless_sig=( ksless<0.01)
  ksgreater_sig=( ksgreater<0.01)
  ks_nonsig=(ksgreater>=0.01 & ksless>=0.01)
  
  rawM_nozero_median=apply(rawM,1,function(x){return(median(x[x>0],na.rm = TRUE))})
  rawM_nozero_mean=apply(rawM,1,function(x){return(mean(x[x>0],na.rm = TRUE))})
  rawM_nozero_sd=apply(rawM,1,function(x){return(sd(x[x>0],na.rm = TRUE))})
  rawM_nozero_skewness=apply(rawM,1,function(x){return(skewness(x[x>0],na.rm = TRUE))})
  rawM_nozero_max=apply(rawM,1,function(x){return(max(x[x>0],na.rm = TRUE))})
  
  hist(rawM_nozero_median[kstwoside_sig],breaks=20, main="median of nozero log-expres of genes, kstwoside sig")
  hist(rawM_nozero_median[ksless_sig],breaks=20, main="median of nozero log-expres of genes, ksless sig")
  hist(rawM_nozero_median[ksgreater_sig],breaks=20, main="median of nozero log-expres of genes,ksgreater sig")
  hist(rawM_nozero_median[ks_nonsig],breaks=20, main="median of nozero log-expres of genes,ks no sig")
  
  hist(rawM_nozero_mean[kstwoside_sig],breaks=20, main="mean of nozero log-expres of genes, kstwoside sig")
  hist(rawM_nozero_mean[ksless_sig],breaks=20, main="mean of nozero log-expres of genes, ksless sig")
  hist(rawM_nozero_mean[ksgreater_sig],breaks=20, main="mean of nozero log-expres of genes,ksgreater sig")
  hist(rawM_nozero_mean[ks_nonsig],breaks=20, main="mean of nozero log-expres of genes,ks no sig")
  
  hist(rawM_nozero_sd[kstwoside_sig],breaks=20, main="sd of nozero log-expres of genes, kstwoside sig")
  hist(rawM_nozero_sd[ksless_sig],breaks=20, main="sd of nozero log-expres of genes, ksless sig")
  hist(rawM_nozero_sd[ksgreater_sig],breaks=20, main="sd of nozero log-expres of genes,ksgreater sig")
  hist(rawM_nozero_sd[ks_nonsig],breaks=20, main="sd of nozero log-expres of genes,ks no sig")
  
  hist(rawM_nozero_skewness[kstwoside_sig],breaks=20, main="skewness of nozero log-expres of genes, kstwoside sig")
  hist(rawM_nozero_skewness[ksless_sig],breaks=20, main="skewness of nozero log-expres of genes, ksless sig")
  hist(rawM_nozero_skewness[ksgreater_sig],breaks=20, main="skewness of nozero log-expres of genes,ksgreater sig")
  hist(rawM_nozero_skewness[ks_nonsig],breaks=20, main="skewness of nozero log-expres of genes,ks no sig")
  
  hist(rawM_nozero_max[kstwoside_sig],breaks=20, main="max of nozero log-expres of genes, kstwoside sig")
  hist(rawM_nozero_max[ksless_sig],breaks=20, main="max of nozero log-expres of genes, ksless sig")
  hist(rawM_nozero_max[ksgreater_sig],breaks=20, main="max of nozero log-expres of genes,ksgreater sig")
  hist(rawM_nozero_max[ks_nonsig],breaks=20, main="max of nozero log-expres of genes,ks no sig")
  
  ind_table_ksless=list()
  ind_table_ksnonsig=list()
  
  #focus on special ks sig genes
  select10=0
  for(i in 1:length(fit_ob_pval)){
    if(rawM_0zero_num[i]>50 && ksless[i]<0.01){
      non_zero_flag=rawM[i,]>0
      ind_table_ksless[[i]]=as.numeric(table(meta$individual[non_zero_flag]))
      if(select10<10){
        hist(rawM[i,non_zero_flag],breaks=100,main=paste0("KSless sig: log expression of gene#",i,
                                                          ", pval ob=", round(fit_ob_pval[i],4),
                                                          ", non-zero num=",rawM_0zero_num[i]),
             sub=paste0("ind#: ",length(table(meta$individual[non_zero_flag])),
                        ", diag#: ",length(table(meta$diagnosis[non_zero_flag]))))
        hist(table(meta$individual[non_zero_flag]),breaks=10,
             main=paste0("KSless sig: individual expression cell count of gene#",i))
        select10=select10+1
      }
    }
  }
  
  select10=0
  for(i in 1:length(fit_ob_pval)){
    if(rawM_0zero_num[i]>50  && kstwoside[i]>0.2){
      non_zero_flag=rawM[i,]>0
      ind_table_ksnonsig[[i]]=as.numeric(table(meta$individual[non_zero_flag]))
      if(select10<10){
        hist(rawM[i,non_zero_flag],breaks=50,main=paste0("KS nonsig: log expression of gene#",i,
                                                         ", pval ob=", round(fit_ob_pval[i],4),
                                                         ", non-zero num=",rawM_0zero_num[i]),
             sub=paste0("ind#: ",length(table(meta$individual[non_zero_flag])),
                        ", diag#: ",length(table(meta$diagnosis[non_zero_flag]))))
        hist(table(meta$individual[non_zero_flag]),breaks=10,
             main=paste0("KSless nonsig: individual expression cell count of gene#",i))
        select10=select10+1
      }
      
    }
  }
  
  #if we focus on the large expression cells level.
  hist(rawM_nozero_mean[rawM_0zero_num>50 & kstwoside>0.2],breaks=20)
  hist(rawM_nozero_mean[rawM_0zero_num>50 & kstwoside<0.01],breaks=20,col=rgb(1,0,0,0.3),add=T)
  hist(rawM_nozero_median[rawM_0zero_num>50 & kstwoside>0.2],breaks=20)
  hist(rawM_nozero_median[rawM_0zero_num>50 & kstwoside<0.01],breaks=20,col=rgb(1,0,0,0.3),add=T)
  hist(rawM_nozero_sd[rawM_0zero_num>50 & kstwoside>0.2],breaks=20)
  hist(rawM_nozero_sd[rawM_0zero_num>50 & kstwoside<0.01],breaks=20,col=rgb(1,0,0,0.3),add=T)
  hist(rawM_nozero_skewness[rawM_0zero_num>50 & kstwoside>0.2],breaks=20)
  hist(rawM_nozero_skewness[rawM_0zero_num>50 & kstwoside<0.01],breaks=20,col=rgb(1,0,0,0.3),add=T)
  hist(rawM_nozero_max[rawM_0zero_num>50 & kstwoside>0.2],breaks=20)
  hist(rawM_nozero_max[rawM_0zero_num>50 & kstwoside<0.01],breaks=20,col=rgb(1,0,0,0.3),add=T)
  
  mydata_hist=hist(rawM[rawM_0zero_num>50 & kstwoside>0.2,],breaks=50,plot=F)
  plot(mydata_hist$count+1, log="y", type='h', lwd=10, lend=2,
       main="genes log(expression +1) with least 50 cell expression and kstwoside>0.2")
  
  mydata_hist=hist(rawM[rawM_0zero_num>50 & kstwoside<0.01,],breaks=50,plot=F)
  plot(mydata_hist$count+1, log="y", type='h', lwd=10, lend=2,
       main="genes log(expression +1) with least 50 cell expression and kstwoside<0.01")
  
  
  ind_table_ksless_mean=sapply(ind_table_ksless, function(x){
    if(length(x)>0){return(mean(x))}else{return(NA)}})
  ind_table_ksless_median=sapply(ind_table_ksless, function(x){
    if(length(x)>0){return(median(x))}else{return(NA)}})
  ind_table_ksless_sd=sapply(ind_table_ksless, function(x){
    if(length(x)>0){return(sd(x))}else{return(NA)}})
  ind_table_ksless_skewness=sapply(ind_table_ksless, function(x){
    if(length(x)>0){return(skewness(x))}else{return(NA)}})
  ind_table_ksless_max=sapply(ind_table_ksless, function(x){
    if(length(x)>0){return(max(x))}else{return(NA)}})
  ind_table_ksless_mean=ind_table_ksless_mean[!is.na(ind_table_ksless_mean)]
  ind_table_ksless_median=ind_table_ksless_median[!is.na(ind_table_ksless_median)]
  ind_table_ksless_sd=ind_table_ksless_sd[!is.na(ind_table_ksless_sd)]
  ind_table_ksless_skewness=ind_table_ksless_skewness[!is.na(ind_table_ksless_skewness)]
  ind_table_ksless_max=ind_table_ksless_max[!is.na(ind_table_ksless_max)]
  
  
  ind_table_ksnonsig_mean=sapply(ind_table_ksnonsig, function(x){
    if(length(x)>0){return(mean(x))}else{return(NA)}})
  ind_table_ksnonsig_median=sapply(ind_table_ksnonsig, function(x){
    if(length(x)>0){return(median(x))}else{return(NA)}})
  ind_table_ksnonsig_sd=sapply(ind_table_ksnonsig, function(x){
    if(length(x)>0){return(sd(x))}else{return(NA)}})
  ind_table_ksnonsig_skewness=sapply(ind_table_ksnonsig, function(x){
    if(length(x)>0){return(skewness(x))}else{return(NA)}})
  ind_table_ksnonsig_max=sapply(ind_table_ksnonsig, function(x){
    if(length(x)>0){return(max(x))}else{return(NA)}})
  ind_table_ksnonsig_mean=ind_table_ksnonsig_mean[!is.na(ind_table_ksnonsig_mean)]
  ind_table_ksnonsig_median=ind_table_ksnonsig_median[!is.na(ind_table_ksnonsig_median)]
  ind_table_ksnonsig_sd=ind_table_ksnonsig_sd[!is.na(ind_table_ksnonsig_sd)]
  ind_table_ksnonsig_skewness=ind_table_ksnonsig_skewness[!is.na(ind_table_ksnonsig_skewness)]
  ind_table_ksnonsig_max=ind_table_ksnonsig_max[!is.na(ind_table_ksnonsig_max)]
  
  
  
  hist(ind_table_ksless_mean,breaks=50)
  hist(ind_table_ksnonsig_mean,breaks=50)
  
  hist(ind_table_ksless_median,breaks=50)
  hist(ind_table_ksnonsig_median,breaks=50)
  
  hist(ind_table_ksless_sd,breaks=50)
  hist(ind_table_ksnonsig_sd,breaks=50)
  
  hist(ind_table_ksless_skewness,breaks=50)
  hist(ind_table_ksnonsig_skewness,breaks=50)
  
  hist(ind_table_ksless_max,breaks=50)
  hist(ind_table_ksnonsig_max,breaks=50)
  dev.off()
  
  
  #######ks vs perm pvalues###################
  pdf(paste0("Stat_non-uniform_pval_permutated_",cluster_tag,".pdf"),width=6,height=6)
  plot(apply(fit_perm,1,median),-log10(kstwoside),cex=.2)
  plot(apply(fit_perm,1,median),-log10(ksless),cex=.2)
  plot(apply(fit_perm,1,median),-log10(ksgreater),cex=.2)
  
  plot(-log10(ksgreater),-log10(ksless),cex=.2,
       main=paste0("sig_KSgreater: ",round(sum(ksgreater<0.01)*100/length(ksgreater),3),
                   "%, sig_KSless: ",round(sum(ksless<0.01)*100/length(ksless),3),"%"))
  
  plot(perm_pval1_rate,-log10(ksgreater),cex=.2,
       main=paste0("cor: ",round(cor(perm_pval1_rate,-log10(ksgreater)),3)))
  
  
  ks_sig_flag=pmin(ksless,ksgreater)<0.01
  
  #now we restrict our focus on the perm_pval1_rate<0.2
  ksgreater0.2=ksgreater[perm_pval1_rate<0.2]
  ksless0.2=ksless[perm_pval1_rate<0.2]
  ks_sig_flag0.2=ks_sig_flag[perm_pval1_rate<0.2]
  
  
  plot(apply(fit_perm,1,median)[perm_pval1_rate<0.2],-log10(ksless0.2),cex=.2)
  plot(apply(fit_perm,1,median)[perm_pval1_rate<0.2],-log10(ksgreater0.2),cex=.2)
  plot(-log10(ksgreater0.2),-log10(ksless0.2),cex=.2,
       main=paste0("sig_KSgreater0.2: ",round(sum(ksgreater0.2<0.01)*100/length(ksgreater0.2),3),
                   "%, sig_KSless0.2: ",round(sum(ksless0.2<0.01)*100/length(ksless0.2),3),"%"))
  
  
  #we found that the ks_less have 40% significant ununiform distribution. We will digging out for that.
  
  
  hist(fit_ob_pval[ksless_sig],breaks=20, main="observed pvalues with pval1_rate<0.2,ksless sig")
  hist(fit_ob_pval[ksgreater_sig],breaks=20, main="observed pvalues with pval1_rate<0.2,ksgreater sig")
  hist(fit_ob_pval[ks_nonsig],breaks=20, main="observed pvalues with pval1_rate<0.2,ks no sig")
  
  hist(rawp[ksless_sig],breaks=20, main="permutation pvalues with pval1_rate<0.2,ksless sig")
  hist(rawp[ksgreater_sig],breaks=20, main="permutation pvalues with pval1_rate<0.2,ksgreater sig")
  hist(rawp[ks_nonsig],breaks=20, main="permutation pvalues with pval1_rate<0.2,ks no sig")
  
  hist(fit_perm[ksless_sig,],breaks=20, main="pvalues from permutation data with pval1_rate<0.2,ksless sig")
  hist(fit_perm[ksgreater_sig,],breaks=20, main="pvalues from permutation data with pval1_rate<0.2,ksgreater sig")
  hist(fit_perm[perm_pval1_rate<0.2 & ksgreater>=0.01 & ksless>0.01,],breaks=20, main="pvalues from permutation data with pval1_rate<0.2,ks no sig")
  
  dev.off()
}


#sessionInfo()
#q(save="no")
