library(data.table)
library(tm)
library(topicmodels)
library(slam)
library(wordcloud)

## read
data <- fread("~/Documents/CSE190_Data/cens_tweets_seg.csv")
names(data) <- "text"
text <- enc2utf8(data$text)
stopwords <- read.table("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/stopwords.txt")
stopwords <- enc2utf8(as.character(stopwords$V1))

## clean
## remove everything that starts with a u
text <- gsub("u.*", "", text)
text.source <- Corpus(VectorSource(text))
text.dtm <- DocumentTermMatrix(text.source,
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
