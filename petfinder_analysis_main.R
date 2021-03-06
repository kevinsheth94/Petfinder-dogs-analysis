#######################################################
### Data Science for Business - Decision 520Q
### Project - Pet Adoption
### Team B28
### Alex Blaine, Arika Reddy, Kevin Sheth, Holly Yuan
#######################################################
### Housekeeping for packages
options(warn=-1)
source("DataAnalyticsFunctions.R")
source("PerformanceCurves.R")
installpkg("psych")
installpkg("dplyr")
installpkg("ggplot2")
installpkg("glmnet")
installpkg("cluster")
installpkg("tidyverse")
installpkg("corrplot")
installpkg("caret")
installpkg("tree")
installpkg("partykit")
installpkg("kableExtra")
installpkg("randomForest")
installpkg("glmnet")
installpkg("nnet")
installpkg("fpc")
installpkg("GGally")
installpkg("textir")
installpkg("slam")
installpkg("RColorBrewer")
installpkg("SnowballC")
installpkg("keras")
installpkg("MASS")
library(MASS)
library(fpc)
library(tidyverse)
library(nnet)
library(randomForest)
library(glmnet)
library(kableExtra)
library(tree)
library(partykit)
library(caret)
library(corrplot)
library(psych)
library(dplyr)
library(ggplot2)
library(glmnet)
library(cluster)
library(GGally)
library(textir)
library(slam)
library(RColorBrewer)
library(SnowballC)
library(tm)
library(wordcloud)
update.packages("tm",  checkBuilt = TRUE)
library(keras)
#install_keras()

### Load data
petData = read_csv('train.csv')

#######################################################
### Data Cleaning
petData$Description = as.character(petData$Description)
petData$Name = iconv(petData$Name, "latin1", "ASCII", sub="")
petData$Description = iconv(petData$Description, "latin1", "ASCII", sub="")
petData$DescCount = str_length(petData$Description)
new = data.frame(petData$Type,petData$Description, petData$AdoptionSpeed)
### Drop unwanted columns
names(petData)
columnsToDrop = c("Description","PetID","RescuerID")
petDataFil <- petData[,!(names(petData) %in% columnsToDrop)]
names(petDataFil)

### Check if a pet has a name
petDataFil$HasName=ifelse(is.na(petDataFil$Name),0,1)
petDataFil$Name<-NULL
### Create new dummy for breed type (purebred or mixedbred)
petDataFil$Breed2=ifelse(petDataFil$Breed1==petDataFil$Breed2,0,petDataFil$Breed2)
petDataFil$PureBred=ifelse(petDataFil$Breed1==0 | petDataFil$Breed2==0,0,1)

### Create new dummy for adoption speed (fast for within a month)
petDataFil$FastAdoptionSpeed = ifelse(petDataFil$AdoptionSpeed<3,1,0)
petDataFil$AdoptionSpeed<-NULL

### Transform data to address outliers
### log(age+1), log(DescCharCount), log(photoamt+1), 
### drop videoamt, make single dog, drop quantity, make free/paid, drop fee
petDataFil$l.Age <- log(petDataFil$Age+1)
petDataFil$l.Desccount <- log(petDataFil$DescCount+1)
petDataFil$l.PhotoAmt <- log(petDataFil$PhotoAmt+1)
petDataFil$JustOnePet <- ifelse(petDataFil$Quantity==1,1,0)
petDataFil$Free <- ifelse(petDataFil$Fee==0,1,0)
petDataFil$Quantity <- NULL
petDataFil$Fee <- NULL
petDataFil$VideoAmt <- NULL
petDataFil$Age <- NULL
petDataFil$PhotoAmt <- NULL
petDataFil$DescCount <- NULL

### Only look at dogs
petDataFilDogs = petDataFil %>% filter(Type==1)
### Delete Type column in the dog dataset
petDataFilDogs$Type<-NULL

### 8132 observations in total with 21 variables
summary(petDataFilDogs)
paste("Missing values in",nrow(petDataFilDogs)-sum(complete.cases(petDataFilDogs)), "observations out of",nrow(petDataFilDogs))

### Correlation matrix
# res <- cor(petDataFilDogs)
# par(mar=c(1,1,1,1),cex.axis=0.3)
# corrplot(res, order = "hclust", tl.col = "black", tl.srt = 45)

### Make into factors - breed1, breed2, color1, color2, color3, 
### vaccinated, dewormed, sterilized, furlength, gender, 
### health, maturitySize, State, BreedType, Free, and JustOneDog
petDataFilDogs$Breed1<-NULL
petDataFilDogs$Breed2<-NULL
petDataFilDogs$HasName=as.factor(petDataFilDogs$HasName)
petDataFilDogs$PureBred=as.factor(petDataFilDogs$PureBred)
petDataFilDogs$FastAdoptionSpeed=as.factor(petDataFilDogs$FastAdoptionSpeed)
petDataFilDogs$Gender=as.factor(petDataFilDogs$Gender)
petDataFilDogs$Color1=as.factor(petDataFilDogs$Color1)
petDataFilDogs$Color2=as.factor(petDataFilDogs$Color2)
petDataFilDogs$Color3=as.factor(petDataFilDogs$Color3)
petDataFilDogs$Vaccinated=as.factor(petDataFilDogs$Vaccinated)
petDataFilDogs$Dewormed=as.factor(petDataFilDogs$Dewormed)
petDataFilDogs$Sterilized=as.factor(petDataFilDogs$Sterilized)
petDataFilDogs$FurLength=as.factor(petDataFilDogs$FurLength)
petDataFilDogs$MaturitySize=as.factor(petDataFilDogs$MaturitySize)
petDataFilDogs$Health=as.factor(petDataFilDogs$Health)
petDataFilDogs$State=as.factor(petDataFilDogs$State)
petDataFilDogs$Free=as.factor(petDataFilDogs$Free)
petDataFilDogs$JustOnePet=as.factor(petDataFilDogs$JustOnePet)
### 8132 observations in total with 19 variables
summary(petDataFilDogs)
### Data Cleaning Ended
#######################################################
### Data visualization
# par(mar=c(1,1,1,1),cex.axis=0.3)
# ggpairs(petDataFilDogs[,c(3,4,5,6,7,8,9,10,11,12,14,15,16,17,18,19,20,21)])
color_labels = read.csv('color_labels.csv')
head(color_labels)
petDataFilDogs$Color1 = as.numeric(paste(petDataFilDogs$Color1))

petDataFilDogs <- left_join(petDataFilDogs, color_labels %>% select(Color1=ColorID, ColorName1=ColorName), by="Color1")

# Histogram of Adoption Speed vs. Color 
a <- ggplot(data=petDataFilDogs, aes(x=petDataFilDogs$FastAdoptionSpeed, fill="ColorName1")) + geom_histogram(stat="count") + facet_wrap(as.factor(petDataFilDogs$ColorName1)) + labs(title ="Histogram of Adoption Speed segregated by Color of Dog", x = "Adoption Speed", y = "Count") + theme(plot.title = element_text(hjust = 0.5)) 
a + scale_x_discrete(breaks=c("0", "1"), labels=c("Slow", "Fast")) + theme(legend.position = "none") +
  theme(strip.background =element_rect(fill="black"))+
  theme(strip.text = element_text(colour = "white"))


# Adoption Speed changes as a result of Age and Gender
petDataFilDogs$newv <- as.factor(ifelse(petDataFilDogs$FastAdoptionSpeed==1,"Adopted within 1 month", "Adopted after 1 month"))
p <- ggplot(data=petDataFilDogs %>% filter(Gender == 1 | Gender == 2), aes(x = Gender, y=l.Age, fill=Gender)) + geom_boxplot() + facet_wrap(~newv) + 
  labs(title ="Adoption Speed changes as a result of Age and Gender", x = "Gender", y = "Log of Age") + theme(plot.title = element_text(hjust = 0.5)) 
p + scale_x_discrete(breaks=c("1", "2"), labels=c("Male", "Female")) + theme(legend.position = "none") +
  theme(strip.background =element_rect(fill="black"))+
  theme(strip.text = element_text(colour = 'white'))


# Adoption Speed by Color and Age
petDataFilDogs$newv <- as.factor(ifelse(petDataFilDogs$FastAdoptionSpeed==1,"Adopted within 1 month", "Adopted after 1 month"))
plot <- ggplot(data=petDataFilDogs, aes(x = as.factor(Color1), y =as.numeric(petDataFilDogs$l.Age), fill = as.factor(Color1))) + geom_boxplot() + facet_wrap(petDataFilDogs$newv) +
  labs(title ="Adoption Speed by Color and Age for Dogs", x = "Colors", y = "Log of Age")
plot + theme(plot.title = element_text(hjust = 0.5)) + 
  scale_x_discrete(breaks=c(1, 2, 3, 4,5,6,7),labels=c("Black", "Brown", "Golden", "Yellow", "Cream", "Gray", "White")) +theme(legend.position = "none")

# Adoption Speed Vs. Log of Age 
ggplot(data = petDataFilDogs, aes(x=petDataFilDogs$FastAdoptionSpeed,y=petDataFilDogs$l.Age, fill=FastAdoptionSpeed))+ geom_boxplot() + labs(title ="Adoption Speed Vs. Log of Age", x = "Adoption Speed", y = "Log of Age")+ theme(plot.title = element_text(hjust = 0.5)) + theme(legend.position = "none")+ scale_x_discrete(breaks=c("0", "1"), labels=c("Slow", "Fast"))

petDataFilDogs$newv <- NULL
petDataFilDogs$ColorName1=NULL
petDataFilDogs$Color1=factor(petDataFilDogs$Color1)

# Adoption Speed by word count
ggplot(data = petDataFilDogs, aes(x = l.PhotoAmt, y = l.Desccount)) + geom_point() + geom_smooth() + facet_grid(~FastAdoptionSpeed)
ggplot(data = petDataFilDogs, aes(x = JustOnePet, y = l.Desccount)) + geom_boxplot() + facet_grid(~FastAdoptionSpeed)
ggplot(data = petData %>% filter(Type==1), aes(x = log(DescCount))) + geom_histogram() + facet_grid(~as.factor(ifelse(AdoptionSpeed<3,"Adopted within 1 month", "Adopted after 1 month")))

# Age and Vaccination Interaction for Adoption Speed
petDataFilDogs$newv <- as.factor(ifelse(petDataFilDogs$Vaccinated==1,"Vaccinated", ifelse(petDataFilDogs$Vaccinated==2, "Not Vaccinated", "Not Sure")))
p <- ggplot(data = petDataFilDogs %>% filter(Vaccinated==1 | Vaccinated == 2), aes(x = FastAdoptionSpeed, y = l.Age, fill = FastAdoptionSpeed)) + geom_boxplot() + facet_wrap(~newv) +
  labs(title ="Age and Vaccination Interaction for Adoption Speed", x = "Adoption Speed", y = "Log of Age")
p + theme(plot.title = element_text(hjust = 0.5)) + scale_x_discrete(breaks=c("0", "1"), labels=c("Slow", "Fast"))+theme(legend.position = "none")
petDataFilDogs$newv <- NULL

#######################################################
### World Cloud
names(new)
newDog <- new %>% filter(petData.Type==1)

ap.corpus <-VCorpus(VectorSource(data.frame(newDog$petData.Description)))
ap.corpus <- tm_map(ap.corpus, content_transformer(tolower))
### remove punctuation
ap.corpus <- tm_map(ap.corpus, removePunctuation)
### remove unhelpful words
ap.corpus <- tm_map(ap.corpus, removeWords, stopwords("english"))
### stemming (remove variations from words)
ap.corpus <- tm_map(ap.corpus, stemDocument)
ap.corpus <- tm_map(ap.corpus, stripWhitespace)
dtm <- TermDocumentMatrix(ap.corpus)
m <- as.matrix(dtm)
v <- sort(rowSums(m),decreasing=TRUE)
d <- data.frame(word = names(v),freq=v)
head(d, 10)
par(mfrow=c(1,1))
wordcloud(words = d$word, freq = d$freq, min.freq = 1,
          max.words=100, random.order=FALSE, rot.per=0.35, 
          colors=brewer.pal(8, "Dark2"))

##############################################################

### Additionally, we want to see if the pet listings can be clustered into different segments
### as we want to understand the listings better
### Therefore we proceed with K-means clustering
### We first used information criterion to pick the number of clusters
train.data  <- petDataFilDogs
xdata <- model.matrix(FastAdoptionSpeed ~ ., data=train.data)[,-1]
xdata <- scale(xdata)
### We decide how many clusters we should have using AIC, BIC and HDIC
kfit <- lapply(1:30, function(k) kmeans(xdata,k))
kaic <- sapply(kfit,kIC)
kbic <- sapply(kfit,kIC,"B")
kHDic <- sapply(kfit,kIC,"C")
### Now we plot them, first we plot AIC
par(mar=c(1,1,1,1),cex.axis=0.8)
par(mai=c(1,1,1,1))
plot(kaic, xlab="k (# of clusters)", ylab="IC (Deviance + Penalty)", 
     ylim=range(c(kaic,kbic,kHDic)), # get them on same page
     type="l", lwd=2)
### Vertical line where AIC is minimized
abline(v=which.min(kaic))
### Next we plot BIC
lines(kbic, col=4, lwd=2)
### Vertical line where BIC is minimized
abline(v=which.min(kbic),col=4)
### Next we plot HDIC
lines(kHDic, col=3, lwd=2)
### Vertical line where HDIC is minimized
abline(v=which.min(kHDic),col=3)
### Insert labels
text(c(which.min(kaic),which.min(kbic),which.min(kHDic)),c(mean(kaic),mean(kbic),mean(kHDic)),c("AIC","BIC","HDIC"))
### both AICc and BIC choose more complicated models
### HDIC suggested 2 clusters
min(kHDic); kHDic
Centers <- kmeans(xdata,4,nstart=30)
### Centers
Centers$centers[1,]
Centers$centers[2,]
Centers$centers[3,]
Centers$centers[4,]
### Sizes of clusters
Centers$size
### variation explained by the clusters
1 - Centers$tot.withinss/ Centers$totss
### only 4.7% variation was explained so we did not find useful information from this
#plotcluster(xdata, Centers$cluster)
### but we still want to see how these segments relate to FastAdoptionSpeed
aggregate(petDataFilDogs$FastAdoptionSpeed==1~Centers$cluster, FUN=mean)

### Next, we also tried PCA to see if certain features can be used to explain our data
### Lets compute the (Full) PCA
pca.data <- prcomp(xdata, scale=TRUE)
### Lets plot the variance that each component explains
par(mar=c(4,4,4,4)+0.3)
plot(pca.data,main="PCA: Variance Explained by Factors", col=rainbow(9))
mtext(side=1, "Factors", line=1, font=2)
summary(pca.data)
### We see that the first three principal components only explain about 15%

### Summary of each Principal Component Score
pc <- predict(pca.data) 
summary(pc)

## Interpreting the four factors
## Next we still try to interpret the meaning of the latent features (PCs)
## to do that we look at the "loadings" which gives me
## the correlation of each factor with each original feature
## Note that it is important to look at the larger correlations (positively or negatively) 
## to see which are the original features that are more important 
## in a factor. We will do it for the first 3 factors.
loadings <- pca.data$rotation[,1:3]
### Loading 1
v<-loadings[order(abs(loadings[,1]), decreasing=TRUE)[1:ncol(xdata)],1]
loadingfit <- lapply(1:ncol(xdata), function(k) ( t(v[1:k])%*%v[1:k] - 3/4 )^2)
v[1:which.min(loadingfit)]
### Not vaccinated/dewormed/sterilized and young
###
### Loading 2
v<-loadings[order(abs(loadings[,2]), decreasing=TRUE)[1:ncol(xdata)],2]
loadingfit <- lapply(1:ncol(xdata), function(k) ( t(v[1:k])%*%v[1:k] - 3/4 )^2)
v[1:which.min(loadingfit)]
### Just one pet, female, know about vet care, second color not brown
###
### Loading 3
v<-loadings[order(abs(loadings[,3]), decreasing=TRUE)[1:ncol(xdata)],3]
loadingfit <- lapply(1:ncol(xdata), function(k) ( t(v[1:k])%*%v[1:k] - 3/4 )^2)
v[1:which.min(loadingfit)]
### Large size, more description, some brown, has photo, older, longer fur, Selangor state

### Data visualization ended
#######################################################
### Modeling

### Need to estimate probability of FastAdoptionSpeed
### Compare different models 
### m.lr : logistic regression
### m.lr.l : logistic regression with interaction using lasso
### m.lr.pl : logistic regression with interaction using post lasso
### m.lr.tree : classification tree

### Step wise selection to remove some features first with logistic regression
m0 <- glm(formula = FastAdoptionSpeed~., data = train.data, family = "binomial")
step.model <- stepAIC(m0,direction="both", trace = FALSE)
summary(step.model)
# Rsq <- 1 - step.model$deviance/step.model$null.deviance; Rsq

### First lets set up the data
### the features need to be a matrix ([,-1] removes the first column which is the intercept)
set.seed(123)
train.data <- subset(train.data, select = -c(State))
Mx<- model.matrix(FastAdoptionSpeed ~ ., data=train.data)[,-1]
My<- train.data$FastAdoptionSpeed == 1
lasso <- glmnet(Mx, My, family="binomial")
lassoCV <- cv.glmnet(Mx, My, family="binomial")

par(mar=c(1.5,1.5,2,1.5))
par(mai=c(1.5,1.5,2,1.5))

plot(lassoCV, main="Fitting Graph for CV Lasso \n \n # of non-zero coefficients  "
     , xlab = expression(paste("log(",lambda,")")))

num.features <- ncol(Mx)
num.n <- nrow(Mx)
num.FastAdoptionSpeed <- sum(My)
w <- (num.FastAdoptionSpeed/num.n)*(1-(num.FastAdoptionSpeed/num.n))
lambda.theory <- sqrt(w*log(num.features/0.05)/num.n)
lassoTheory <- glmnet(Mx,My, family="binomial",lambda = lambda.theory)
summary(lassoTheory)
support(lassoTheory$beta)

lambda.min=lassoCV$lambda.min
lassoMin <- glmnet(Mx,My, family="binomial",lambda = lambda.min)
features.min <- support(lassoMin$beta[,which.min(lambda.min)])
length(features.min)
train.data.min <- data.frame(Mx[,features.min],My)
names(train.data.min)

features.theory <- support(lasso$beta[,which.min(lassoCV$cvm)])
features.theory <- support(lassoTheory$beta)
length(features.theory)
train.data.theory <- data.frame(Mx[,features.theory],My)
names(train.data.theory)

lambda.1se = lassoCV$lambda.1se
features.1se <- support(lasso$beta[,which.min( (lassoCV$lambda-lassoCV$lambda.1se)^2)])
length(features.1se) 
train.data.1se <- data.frame(Mx[,features.1se],My)
names(train.data.1se)

### Model Performance - 10 fold cross validation
### prediction is a probability score
### we convert to 1 or 0 via prediction > threshold
PerformanceMeasure <- function(actual, prediction, threshold=.5) {
  1-mean( abs( (prediction>threshold) - actual ) )  #OOS Accuracy
  #R2(y=actual, pred=prediction, family="binomial") ##OOS R Squared
  #1-mean( abs( (prediction- actual) ) )  
}

n <- nrow(train.data)
nfold <- 10
OOS <- data.frame(m.lr=rep(NA,nfold), m.lr.l.min=rep(NA,nfold), m.lr.l.1se=rep(NA,nfold), m.lr.l.th=rep(NA,nfold), m.lr.pl.min=rep(NA,nfold), m.lr.pl.1se=rep(NA,nfold), m.lr.pl.th=rep(NA,nfold), m.tree=rep(NA,nfold), m.average=rep(NA,nfold)) 
#names(OOS)<- c("Logistic Regression", "Lasso on LR with Interactions", "Post Lasso on LR with Interactions", "Classification Tree", "Average of Models")
foldid <- rep(1:nfold,each=ceiling(n/nfold))[sample(1:n)]
for(k in 1:nfold){
  train <- which(foldid!=k) # train on all but fold `k'
  ### Logistic regression
  m.lr <-glm(FastAdoptionSpeed~., data=train.data, subset=train,family="binomial")
  pred.lr <- predict(m.lr, newdata = train.data[-train,], type="response")
  OOS$m.lr[k] <- PerformanceMeasure(actual=My[-train], pred=pred.lr)
  
  ### the Post Lasso Estimates - min
  m.lr.pl.min <- glm(My~., data=train.data.min, subset=train, family="binomial")
  pred.lr.pl.min <- predict(m.lr.pl.min, newdata = train.data.min[-train,], type="response")
  OOS$m.lr.pl.min[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.pl.min)
  
  ### the Post Lasso Estimates - 1se
  m.lr.pl.1se <- glm(My~., data=train.data.1se, subset=train, family="binomial")
  pred.lr.pl.1se <- predict(m.lr.pl.1se, newdata = train.data.1se[-train,], type="response")
  OOS$m.lr.pl.1se[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.pl.1se)
  
  ### the Post Lasso Estimates - theory
  m.lr.pl.th <- glm(My~., data=train.data.theory, subset=train, family="binomial")
  pred.lr.pl.th <- predict(m.lr.pl.th, newdata = train.data.theory[-train,], type="response")
  OOS$m.lr.pl.th[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.pl.th)
  
  ### the Lasso estimates - min 
  m.lr.l.min  <- glmnet(Mx[train,],My[train], family="binomial",lambda = lassoCV$lambda.min)
  pred.lr.l.min <- predict(m.lr.l.min, newx = Mx[-train,], type="response")
  OOS$m.lr.l.min[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.l.min)
  
  ### the Lasso estimates - 1se  
  m.lr.l.1se  <- glmnet(Mx[train,],My[train], family="binomial",lambda = lassoCV$lambda.theory)
  pred.lr.l.1se <- predict(m.lr.l.1se, newx = Mx[-train,], type="response")
  OOS$m.lr.l.1se[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.l.1se)
  
  ### the Lasso estimates - theory
  m.lr.l.th  <- glmnet(Mx[train,],My[train], family="binomial",lambda = lassoCV$lambda.1se)
  pred.lr.l.th <- predict(m.lr.l.th, newx = Mx[-train,], type="response")
  OOS$m.lr.l.th[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.lr.l.th)
  
  ### the classification tree
  m.tree <- tree(FastAdoptionSpeed~ ., data=train.data, subset=train) 
  pred.tree <- predict(m.tree, newdata = train.data[-train,], type="vector")
  pred.tree <- pred.tree[,2]
  OOS$m.tree[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.tree)
  
  pred.m.average <- rowMeans(cbind(pred.tree, pred.lr.l.1se,pred.lr.l.min,pred.lr.l.th, pred.lr.pl.min, pred.lr.pl.th, pred.lr.pl.1se, pred.lr))
  OOS$m.average[k] <- PerformanceMeasure(actual=My[-train], prediction=pred.m.average)
  
  print(paste("Iteration",k,"of",nfold,"completed"))
}

colMeans(OOS)
# OOS Accuracy
# m.lr      m.lr.l m.lr.pl.min m.lr.pl.1se      m.tree   m.average 
# 0.6046491   0.6053862   0.6047683   0.6052755   0.5704346   0.6051478 
par(mar=c(7,5,.5,1)+0.1)
barplot(colMeans(OOS), las=2,xpd=FALSE , xlab="", ylim=c(0.5,0.62), ylab = bquote( "Average Out of Sample Performance"))

### Post Lasso very similar to Average of models.
### Post Lasso and Average better in OOS Accuracy

### the Post Lasso Estimates (1se)
train <- which(foldid!=1)
m.lr.pl <- glm(My~., data=train.data.1se, subset=train, family="binomial")
pred.lr.pl <- predict(m.lr.pl, newdata=train.data.1se[-train,], type="response")
par(mar=c(1,1,1,1))
par(mai=c(1,1,1,1))
hist(pred.lr.pl, breaks = 40, main="Predictions for Post Lasso (theory)")

### We use the Post Lasso Estimates for simplicity
### and we run the method in the whole sample
m.lr.pl <- glm(My~., data=train.data.1se, family="binomial")
summary(m.lr.pl)$coef[,1]
pred.lr.pl <- predict(m.lr.pl, newdata=train.data.1se, type="response")

###
### We can make predictions using the rule
### if hat prob >= threshold, we set hat Y= 1
### otherwise we set hat Y= 0
### threshold = .75  and then .25
# PL.performance75 <- FPR_TPR(pred.lr.pl>=0.75 , My)
# PL.performance75
# PL.performance25 <- FPR_TPR(pred.lr.pl>=0.25 , My)
# PL.performance25
### threshold = .5
PL.performance <- FPR_TPR(pred.lr.pl>=0.5 , My)
PL.performance
confusion.matrix <- c( sum(pred.lr.pl>=0.5) *PL.performance$TP,  sum(pred.lr.pl>=0.5) * PL.performance$FP,  sum(pred.lr.pl<0.5) * (1-PL.performance$TP),  sum(pred.lr.pl<0.5) * (1-PL.performance$FP) )
confusion.matrix

par(mar=c(5,5,3,5))
roccurve <-  roc(p=pred.lr.pl, y=My, bty="n")
#cumulative <- cumulativecurve(p=pred.lr.pl,y=My)
lift <- liftcurve(p=pred.lr.pl,y=My)

#################################################
### Neural Network
### Split into train and test data
trainIndex <- createDataPartition(petDataFilDogs$FastAdoptionSpeed, p = .8, list = FALSE, times = 1)
train.data = petDataFilDogs[trainIndex,]
test.data = petDataFilDogs[-trainIndex,]
mean(train.data$FastAdoptionSpeed==1)
mean(test.data$FastAdoptionSpeed==1)
x.holdout<- model.matrix(FastAdoptionSpeed ~ ., data=test.data)[,-1]
y.holdout<- test.data$FastAdoptionSpeed == 1

x.data<- model.matrix(FastAdoptionSpeed ~ ., data=train.data)[,-1]
y.data<- train.data$FastAdoptionSpeed == 1

#rescale (to be between 0 and 1)
x_train <- x.data %*% diag(1/apply(x.data, 2, function(x) max(x, na.rm = TRUE)))
y_train <- as.numeric(y.data)
x_test <- x.holdout %*% diag(1/apply(x.data, 2, function(x) max(x, na.rm = TRUE)))
y_test <- as.numeric(y.holdout) 

#rescale (unit variance and zero mean)
mean <- apply(x.data,2,mean)
std <- apply(x.data,2,sd)
x_train <- scale(x.data,center = mean, scale = std)
y_train <- as.numeric(y.data)
x_test <- scale(x.holdout,center = mean, scale = std)
y_test <- as.numeric(y.holdout) 

num.inputs <- ncol(x_test)

model <- keras_model_sequential() %>%
  layer_dense(units=64, kernel_regularizer = regularizer_l2(0.001), activation="relu",input_shape = c(num.inputs)) %>%
  layer_dropout(rate=0.3) %>%
  layer_dense(units=64, kernel_regularizer = regularizer_l2(0.001), activation="relu") %>%
  layer_dropout(rate=0.3) %>%
  layer_dense(units=32, kernel_regularizer = regularizer_l2(0.001), activation="relu") %>%
  layer_dropout(rate=0.3) %>%
  layer_dense(units=1,activation="sigmoid")


model %>% compile(
  loss = 'binary_crossentropy',
  optimizer = optimizer_rmsprop(),
  metrics = c('accuracy')
)

history <- model %>% fit(
  x_train, y_train, 
  epochs = 50, batch_size = 256, 
  validation_split = 0.2
)
results.NN <- model %>% evaluate(x_train,y_train)
results.NN

results.NN <- model %>% evaluate(x_test,y_test)
results.NN

pred.NN <- model%>% predict(x_test)
PerformanceMeasure(actual=y_test, prediction=pred.NN, threshold=.5)
