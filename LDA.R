library(data.table)
library(tm)
library(topicmodels)
library(slam)
library(wordcloud)

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
uid.list <- unique(c(cens$uid, cens$retweeted_uid, noncens$uid, noncens$retweeted_uid))
write.table(uid.list, "~/Documents/CSE190_Data/uid_list.csv", row.names = FALSE, col.names = "uid")

#####################################################################

stopwords <- read.table("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/stopwords.txt")
stopwords <- enc2utf8(as.character(stopwords$V1))


## clean
## remove everything that starts with a u
cens.text <- gsub("u.*", "", cens.text)
cens.text.source <- Corpus(VectorSource(cens.text))
cens.text.dtm <- DocumentTermMatrix(cens.text.source,
                               control = list(removePunctuation = T,
                                              removeNumbers = T,
                                              stopwords = stopwords,
                                              wordLengths = c(2, Inf)))


## wordcloud
stopwords.temp <- c(stopwords, "link", "the", "via")
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
