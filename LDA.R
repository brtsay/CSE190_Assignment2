library(data.table)
library(tm)
library(topicmodels)
library(slam)
library(wordcloud)
library(LiblineaR)
library(SparseM)
library(Matrix)


## generate train, validation, test sets
cens.tweet <- fread("~/Documents/CSE190_Data/cens_tweets_seg.csv")
names(cens.tweet) <- "text"
cens.text <- enc2utf8(cens.tweet$text)
noncens.tweet <- fread("~/Documents/CSE190_Data/noncens_tweets_seg.csv")
names(noncens.tweet) <- "text"
noncens.text <- enc2utf8(noncens.tweet$text)
cens <- fread("~/Documents/CSE190_Data/censoredTweets.csv")
## data.table broken for this
noncens <- read.csv("~/Documents/CSE190_Data/noncensoredTweets.csv", stringsAsFactors = FALSE)
## combine with segmented text
cens.seg <- data.table(cens, cens.text)
noncens.seg <- data.table(noncens, noncens.text)
## remove original non segmented text
cens.seg[,text:= NULL]
noncens.seg[,text:=NULL]
names(cens.seg)[12] <- "text"
names(noncens.seg)[12] <- "text"

## create sets
cens.row <- nrow(cens.seg)
noncens.row <- nrow(noncens.seg)
cens.seg <- cens.seg[sample(cens.row),]
noncens.seg <- noncens.seg[sample(noncens.row),]

train <- rbind(cens.seg[1:as.integer(cens.row/2)], noncens.seg[1:as.integer(cens.row/2)])
valid <- rbind(cens.seg[as.integer(cens.row/2+1):as.integer(cens.row/4*3)], noncens.seg[as.integer(cens.row/2+1):as.integer((cens.row/2 + noncens.row)/2)])
test <- rbind(cens.seg[as.integer(cens.row/4*3+1):cens.row], noncens.seg[as.integer((noncens.row+cens.row/2)/2+1):noncens.row])

write.table(train, "~/Documents/CSE190_Data/pre_train.csv", row.names = F, sep = ",")
write.table(valid, "~/Documents/CSE190_Data/pre_valid.csv", row.names = F, sep = ",")
write.table(test, "~/Documents/CSE190_Data/pre_test.csv", row.names = F, sep = ",")

## generate UIDs for making dictionary
train <- fread("~/Documents/CSE190_Data/pre_train.csv")
uid.list <- sort(unique(c(train$uid, train$retweeted_uid)), decreasing=TRUE)
write.table(uid.list, "~/Documents/CSE190_Data/uid_list.csv", row.names = FALSE, col.names = "uid")

#####################################################################
## setwd("/mainstorage/briant/mpsaweibo/CSE190")
setwd("/home/b/Documents/CSE190_Data")

stopwords <- read.table("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/stopwords.txt")
## stopwords <- read.table("stopwords.txt")
stopwords <- enc2utf8(as.character(stopwords$V1))


## clean (run on server)
## text <- c(train$text, valid$text, test$text)
## text <- gsub("u.*?\\s", "", text)
## text.source <- Corpus(VectorSource(text))
## text.dtm <- DocumentTermMatrix(text.source,
##                                control = list(removePunctuation = T,
##                                               removeNumbers = T,
##                                               stopwords = stopwords,
##                                               wordLengths = c(2, Inf),
##                                               weighting = function (x) weightTfIdf(x)
##                                               ))

## load in data
train <- fread("pre_train.csv")
valid <- fread("pre_valid.csv")
test <- fread("pre_test.csv")

## descriptives
all <- rbind(train, valid, test)
## censored
prodStats <- function(data) {
    n.cens <- sum(data$permission_denied, na.rm=TRUE)
    n.noncens <- nrow(data) - sum(data$permission_denied, na.rm=TRUE)
    n <- nrow(data)
    n.retweet <- nrow(data[data$retweeted_uid != ""])
    n.user <- length(unique(data$uid))
    return(list(n.cens, n.noncens, n, n.retweet, n.user))
}

## load in text dtm
train <- fread("pre_train.csv")
valid <- fread("pre_valid.csv")
test <- fread("pre_test.csv")
attach("text_dtm.RData")

train.feat <- fread("train_feat.csv")
valid.feat <- fread("valid_feat.csv")
test.feat <- fread("test_feat.csv")

mergeFeatures <- function(set, feat, text.dtm) {
    feat <- as.simple_triplet_matrix(feat)
    ## combine features and bag of words
    X <- cbind(text.dtm, feat)
    ## X <- text.dtm
    ## convert to format that liblinear can use
    X <- sparseMatrix(X$i, X$j, x=X$v)
    X <- as(X, "matrix.csr")
    y <- set$permission_denied
    y[is.na(y)] <- 0
    return(list(X,y))
}

findError <- function(pred, true) {sum(abs(pred$predictions - true)/length(true))}

## baseline

## loop for multiple sparseness
## sparseness <- c(0.99, 0.999, 0.9999, 0.99999)
## 48, 1451, 12849, 66771
## sparseness <- c(0.995, 0.999999)
## 141, 229334
sparseness <- c(0.99, 0.995, 0.999, 0.9999, 0.99999, 0.999999)
## [1]     48    141   1451  12849  66771 229334
logit.errors <- rep(0, length(sparseness))
svm.errors <- rep(0, length(sparseness))
num.terms <- rep(0, length(sparseness))

## sparseness
for (i in 1:length(sparseness)) {
    dtm <- removeSparseTerms(text.dtm, sparseness[i])
    ## dtm <- text.dtm
    num.terms[i] <- length(Terms(dtm))
    print(num.terms)
    train.text.dtm <- dtm[1:nrow(train),]
    valid.text.dtm <- dtm[(nrow(train)+1):(nrow(train)+nrow(valid)),]
    test.text.dtm <- dtm[(nrow(train)+nrow(valid)+1):nrow(text.dtm),]
    
    train.data <- mergeFeatures(train, train.feat, train.text.dtm)
    valid.data <- mergeFeatures(valid, valid.feat, valid.text.dtm)
    test.data <- mergeFeatures(test, test.feat, test.text.dtm)

    ## train
    logit.model <- LiblineaR(train.data[[1]], train.data[[2]])
    pred.logit <- predict(logit.model, valid.data[[1]])
    logit.error <- findError(pred.logit, valid.data[[2]])
    print(paste("logit:", logit.error))
    logit.errors[i] <- logit.error

    svm.model <- LiblineaR(train.data[[1]], train.data[[2]], type = 1)
    pred.svm <- predict(svm.model, valid.data[[1]])
    svm.error <- findError(pred.svm, valid.data[[2]])
    print(paste("svm:", svm.error))
    svm.errors[i] <- svm.error
}

## svm.terms.cost <- data.frame(num.terms, (1-svm.errors))
## names(svm.terms.cost) <- c("num.terms", "acc")
## logit.terms.cost <- data.frame(num.terms, (1-logit.errors))
## names(logit.terms.cost) <- c("num.terms", "acc")

## svm.results <- data.frame(num.terms, (1-errors))
temp.logit <- data.frame(num.terms, (1-logit.errors))
names(temp.logit) <- c("num.terms", "acc")
temp.svm <- data.frame(num.terms, (1-svm.errors))
names(temp.svm) <- c("num.terms", "acc")

svm.terms.cost <- rbind(svm.terms.cost, temp.svm)
logit.terms.cost <- rbind(logit.terms.cost, temp.logit)
svm.terms.cost <- svm.terms.cost[order(svm.terms.cost$num.terms),]
logit.terms.cost <- logit.terms.cost[order(logit.terms.cost$num.terms),]


save(svm.nterms, file = "svm_nterms.RData")



png("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/valid_numTerms.png")

plot(svm.terms.cost, type='o', log = "x",
     main = "Validation Set Accuracy (Cost = 1)",
     xlab = "Number of Terms", ylab = "Accuracy")
lines(logit.terms.cost, type="o", pch = 0, lty=2, col = "blue")
legend(50, 0.926, lty = c(1, 2), pch = c(1,0), col=c("black", "blue"),c("SVM (L2)", "Logistic (L2)"))

dev.off()


costs <- c(1e-4, 1e-3, 1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4)
svm.errors <- rep(0, length(costs))
logit.errors <- rep(0, length(costs))

for (i in 1:length(costs)) {
    ## 1451 terms (.999)
    ## 12849 terms (.9999)
    dtm <- removeSparseTerms(text.dtm, 0.9999)
    ## dtm <- text.dtm
    
    train.text.dtm <- dtm[1:nrow(train),]
    valid.text.dtm <- dtm[(nrow(train)+1):(nrow(train)+nrow(valid)),]
    test.text.dtm <- dtm[(nrow(train)+nrow(valid)+1):nrow(text.dtm),]
    
    train.data <- mergeFeatures(train, train.feat, train.text.dtm)
    valid.data <- mergeFeatures(valid, valid.feat, valid.text.dtm)
    test.data <- mergeFeatures(test, test.feat, test.text.dtm)

    ## train
    print(costs[i])
    ## svm.model <- LiblineaR(train.data[[1]], train.data[[2]], type = 1, cost = costs[i])
    ## pred.svm <- predict(svm.model, valid.data[[1]])
    ## svm.error <- findError(pred.svm, valid.data[[2]])
    ## print(paste("SVM:", svm.error))
    ## svm.errors[i] <- svm.error
    logit.model <- LiblineaR(train.data[[1]], train.data[[2]], type = 0, cost = costs[i])
    pred.logit <- predict(logit.model, valid.data[[1]])
    logit.error <- findError(pred.logit, valid.data[[2]])
    print(paste("LOGIT:", logit.error))
    logit.errors[i] <- logit.error
}

## cost.df <- data.frame(costs, errors)
logit.df <- data.frame(costs, (1-logit.errors))
svm.df <- data.frame(costs, (1-svm.errors))

## attach John's errors.Rdata
attach("errors.Rdata")
jlogit.df <- data.frame(costs, (1-logit.errors.costs))
jsvm.df <- data.frame(costs, (1-svm.errors.costs))

png("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/valid_cost.png")

plot(svm.df, log="x", type="o",
     main="Validation Set Accuracy (Cost)",
     xlab = "Cost", ylab = "Accuracy")
lines(logit.df, log="x", type = "o", pch = 0, lty = 2,  col = "blue")
lines(jsvm.df, log="x", type = "o", pch = 2, lty = 3, col = "red")
lines(jlogit.df, log="x", type = "o", pch=3, lty=4, col = "orange")
legend(1e-4, 0.90, lty = c(1, 2,3,4), pch = c(1,0,2,3), col=c("black", "blue", "red", "orange"), c("BoW SVM (1451 terms)", "BoW Logit (12849 terms)", "LDA SVM (50 topics)", "LDA Logit (50 topics)"))

dev.off()




## dtm <- removeSparseTerms(text.dtm, 0.9999)
dtm <- text.dtm
train.text.dtm <- dtm[1:nrow(train),]
valid.text.dtm <- dtm[(nrow(train)+1):(nrow(train)+nrow(valid)),]
test.text.dtm <- dtm[(nrow(train)+nrow(valid)+1):nrow(text.dtm),]

train.data <- mergeFeatures(train, train.feat, train.text.dtm)
valid.data <- mergeFeatures(valid, valid.feat, valid.text.dtm)
test.data <- mergeFeatures(test, test.feat, test.text.dtm)

## train
model <- LiblineaR(train.data[[1]], train.data[[2]], type=1)
pred.valid <- predict(model, valid.data[[1]])
print(findError(pred.valid, valid.data[[2]]))

## SVM
## no sparse remove: error = 0.09643682
## .99 (17) sparse remove: error = 0.07754799
## .999 (915): error = 0.07251332
## .9999 (9193): error = 0.09071829
## lowest error appears to be 0.999 (915) 0.9274867 (acc)



## pred.train <- predict(model, train.X)

## wordcloud
stopwords.temp <- c(stopwords, "link", "the", "via")
## cens <- fread("cens_tweets_seg.csv")
cens <- fread("noncens_tweets_seg.csv")
## cens <- gsub("u\\w+ *", "", cens$text)
cens <- unlist(lapply(cens, function(x) gsub("[A-Za-z0-9]\\w+ *", "", x)))
text.source <- Corpus(VectorSource(cens))
text.source <- tm_map(text.source, removePunctuation)
text.source <- tm_map(text.source, removeNumbers)
text.source <- tm_map(text.source, removeWords, stopwords.temp)



## png("wc_cens.png")
png("wc_noncens.png")
wordcloud(text.source, max.words = 150, colors = brewer.pal(8,"Dark2"))
dev.off()


## get rid of empty rows so that lda can proceed
row.totals <- rowapply_simple_triplet_matrix(text.dtm, sum)
empty.rows <- text.dtm[row.totals == 0, ]$dimnames[1][[1]]
text.source.nempty <- text.source[-as.numeric(empty.rows)]
## remake dtm
text.dtm <- DocumentTermMatrix(text.source.nempty,
                               control = list(removePunctuation = T,
                                              removeNumbers = T,
                                              stopwords = stopwords,
                                              wordLengths = c(2, Inf)))


## lda
text.ctm <- CTM(text.dtm, k=10)
Topics <- topics(text.ctm)
Terms <- terms(text.ctm, 10)

#####################################################################
## might need later?
## train.text <- train$text
## remove everything that starts with a u
## train.text <- gsub("u.*", "", train.text)
## train.text.source <- Corpus(VectorSource(train.text))
## train.text.dtm <- DocumentTermMatrix(train.text.source,
##                                control = list(removePunctuation = T,
##                                               removeNumbers = T,
##                                               stopwords = stopwords,
##                                               wordLengths = c(2, Inf),
##                                               weighting = function (x) weightTfIdf(x)
##                                               ))
## train.terms <- Terms(train.text.dtm)

## valid <- fread("pre_valid.csv")
## valid.text <- valid$text
## ## remove everything that starts with a u
## valid.text <- gsub("u.*", "", valid.text)
## valid.text.source <- Corpus(VectorSource(valid.text))
## valid.text.dtm <- DocumentTermMatrix(valid.text.source,
##                                control = list(removePunctuation = T,
##                                               removeNumbers = T,
##                                               stopwords = stopwords,
##                                               wordLengths = c(2, Inf),
##                                               dictionary = train.terms,
##                                               weighting = function (x) weightTfIdf(x)
##                                               ))
