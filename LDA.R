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
## text <- gsub("u.*", "", text)
## text.source <- Corpus(VectorSource(text))
## text.dtm <- DocumentTermMatrix(text.source,
##                                control = list(removePunctuation = T,
##                                               removeNumbers = T,
##                                               stopwords = stopwords,
##                                               wordLengths = c(2, Inf),
##                                               weighting = function (x) weightTfIdf(x)
##                                               ))
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

## dtm <- removeSparseTerms(text.dtm, 0.9999)
train.text.dtm <- dtm[1:nrow(train),]
valid.text.dtm <- dtm[(nrow(train)+1):(nrow(train)+nrow(valid)),]
test.text.dtm <- dtm[(nrow(train)+nrow(valid)+1):nrow(text.dtm),]

train.data <- mergeFeatures(train, train.feat, train.text.dtm)
valid.data <- mergeFeatures(valid, valid.feat, valid.text.dtm)
test.data <- mergeFeatures(test, test.feat, test.text.dtm)

## train
model <- LiblineaR(train.data[[1]], train.data[[2]], cost=0.1)
pred.valid <- predict(model, valid.data[[1]])
print(findError(pred.valid, valid.data[[2]]))

## pred.train <- predict(model, train.X)

## wordcloud
stopwords.temp <- c(stopwords, "link", "the", "via")
cens <- fread("cens_tweets_seg.csv")
text.source <- Corpus(VectorSource(cens))
text.source <- tm_map(text.source, removePunctuation)
text.source <- tm_map(text.source, removeNumbers)
text.source <- tm_map(text.source, removeWords, stopwords.temp)
wordcloud(text.source, min.freq = 50, colors = brewer.pal(8,"Dark2"))

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
