library(data.table)
library(tm)
library(topicmodels)
library(slam)

## read
data <- fread("~/Documents/CSE190_Data/testTweets_seg.csv")
names(data) <- "text"
text <- enc2utf8(data$text[1:10000])
stopwords <- read.table("/media/b/DEF8DBF5F8DBC9C3/Users/B T/Copy/CSE190/Assignment/CSE190_Assignment2/stopwords.txt")
stopwords <- enc2utf8(as.character(stopwords$V1))

## clean
text.source <- Corpus(VectorSource(text))
text.dtm <- DocumentTermMatrix(text.source,
                               control = list(removePunctuation = T,
                                              removeNumbers = T,
                                              stopwords = stopwords,
                                              wordLengths = c(2, Inf)))
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
