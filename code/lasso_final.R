#######################################################################################################################
# Project - Advanced Econometric Methods
# Erik Senn, Johannes Cordier, Mila Gorkun-Voevoda, Davia Kündig and Jeremia Stalder
#
# Description:
# Lasso
# Estimated computation time: around 10 minutes

# ------------------------- Libraries ---------------------------------
library(ATE)
library(bbemkr)
library(tidyverse)
library(glmnet)

# ----------------------------------------------------------------------

load("./output/mydata_transform.Rdata")
load("./output/variable_sets_modelling.Rdata")


######Data prep####
lassodata <- mydata_transform
#Xvars <- c(variable_sets_modelling[["independent_vars_std"]][1:(length(variable_sets_modelling[["independent_vars_std"]])-2)])
X <- select(lassodata, c(variable_sets_modelling[["independent_vars_std"]]))
X <- select(X, -c("e401_std"))
D <- select(lassodata, c("e401"))
Y <- select(lassodata, c("tw_adjust_original"))
C <- select(lassodata, c("inc_quintile"))


#Creating all possible cross variables
cr <- factorial(ncol(X))/(factorial(2)*factorial(ncol(X)-2))
crv <- data.frame(matrix(NA, ncol = cr, nrow = nrow(X)))
col <- 1
for (n in 1:(ncol(X)-1)) {
 for (j in (n):(ncol(X)-1)) {
    crv[,col] <- X[,n]*X[,j]
    colnames(crv)[col] <- paste(colnames(X)[n],colnames(X)[j], sep = "*")
    col <- col + 1
}
}


X <- cbind(X, crv)

#Y_cate <- Y
#D_cate <- D
#X_cate <- X

#####Function lasso######
postlasso <- function(Y_cate,D_cate,X_cate){#input in matrix Y= outcome, X covariates including D,
  
  data_cate <- as.matrix(cbind(D_cate,X_cate))
  Y_cate <- as.matrix(Y_cate)
  
  
  lasso.cv <- cv.glmnet(data_cate, Y_cate, type.measure = "mse", family = "gaussian", nfolds = 15, alpha = 1)
  model <- glmnet(data_cate, Y_cate, alpha = 1, family = "gaussian",
                  lambda = lasso.cv$lambda.1se)
  coef_lasso1 <- coef(lasso.cv, s = lasso.cv$lambda.1se)
  variables <- coef_lasso1@Dimnames[[1]][which(coef_lasso1 != 0 ) ]
  
  data_post <- as.data.frame(cbind(data_cate, Y_cate))
  postlasso <- lm(as.formula(paste("tw_adjust_original ~ e401 + ", paste(variables[2:length(variables)], collapse= "+"))), data = data_post)
  
  plasso_ATE <- postlasso$coefficients[["e401"]]
  plasso_SE <- plasso_SE <- coef(summary(postlasso))["e401","Std. Error"]
  
  TE <- c(plasso_ATE, plasso_SE)
  output <- list(TE,variables)
  return(output)
}

#####Function Cate Lasso####
cata_lasso <- function(Y,D,X,C){#Y = outcome, X=covariates  D= e401, C= conditional varibale
  output_matrix <- matrix(NA, 6, 2)
  colnames(output_matrix) <- c("Coef","SE")
  rownames(output_matrix) <- c("ATE", "CATE q1", "CATE q2", "CATE q3", "CATE q4", "CATE q5")
  names_list <- list(1,2,3,4,5,6)
  X_vars <- colnames(X)
  Y_vars <- colnames(Y)
  D_vars <- colnames(D)
  #Combine the three dataframes
  dat <- as.data.frame(cbind(Y,D,X,C))
  colnames(dat)[ncol(dat)] <- "quintile"
  
  
  for (n in 1:5) {
    
    #dat_n <- dat[dat[,"quantile"] == n]#split into quantile datasets
    #dat_n <- dat[dat[,"quintile"] == n]
    
    dat_n <- dat[which(dat$quintile == n),]
    #seperate datasets
    Y_cate <- as.matrix(select(dat_n, all_of(Y_vars)))
    X_cate <- as.matrix(select(dat_n, all_of(X_vars)))
    D_cate <- as.matrix(select(dat_n, all_of(D_vars)))
    output <- postlasso(Y_cate, D_cate ,X_cate)
    output_matrix[n+1,] <- output[[1]]
    names_list[[n+1]] <- output[[2]]
    
  }
  
  #ATE
  output_ate <- postlasso(Y,D,X)
  output_matrix[1,] <- output_ate[[1]]
  names_list[[1]] <- output_ate[[2]]
  
  output_list <- list(names_list,output_matrix)
  return(output_list)
}



#####Output#####
lasso_output <- cata_lasso(Y,D,X,C)

####Rescale everything
#mu <- mean(mydata_transform$tw_adjust_or)
#sd <- sd(mydata_transform$e401)
lasso_table <- lasso_output[[2]]

#lasso_table[,1] <- (lasso_table[,1]*sd)+ mu
#lasso_table[,2] <- lasso_table[,2]*sd
  
#Confidence Intervals
CIu <- lasso_output[[2]][,1]+(1.96*lasso_output[[2]][,2])
CIl <- lasso_output[[2]][,1]-(1.96*lasso_output[[2]][,2])

lasso_table<- cbind(lasso_table,CIl,CIu)


####Save Outputtable#####
save(lasso_table, file = "./output/results/lasso/lasso_output_final.RData")
save(lasso_output, file = "./output/results/lasso/lasso_output_final_inc_variables.RData")
print("Results of Lasso:")
print(lasso_table)