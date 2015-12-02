# CSE190 Assignment 2

<!-- ## TODO List -->
<!-- 1. Validation error plots -->
<!-- 2. Time series chart of censored/total tweets over time (by day or by week?) -->
<!-- 3. Other models e.g. kNN? -->
<!-- 4. Making some sort of baseline from the [original paper](http://www.computer.org/csdl/mags/ic/2013/03/mic2013030042-abs.html). -->
<!-- 5. Adding word cloud of noncensored tweets. -->
<!-- 6. Adding user attributes e.g. province, gender, verified status, etc. -->
<!-- 7. Translating word clouds (this should literally be the last thing to possibly do). -->

## Getting the data
The file **getTweets.py** contains a function that can extract censored and noncensored tweets from the entire dataset. To use it, upload **getTweets.py** to the HNG server and run
```python
from getTweets import *
extractTweets(write_dir, desired_tweets)
```
Here, `write_dir` is a string; it's the directory where you want the function to write the tweet CSV files to. `desired_tweets` is an integer that states how many noncensored tweets you want. The function will not return this exact number but a number close to it. The reason why is because the function generates a random number to determine whether a noncensored tweet gets added or not. 

## Segmenting the data
Use the [Stanford Word Segmenter](http://nlp.stanford.edu/software/segmenter.shtml). Unzip then run the following command from terminal:
```bash
segment.sh ctb [filepath] UTF-8 0 > [new filename]
```
Note that this will actually throw a lot of "private use area codepoint" errors. These are due to the emojis that are used in Weibo. There appear to be [ways](http://stackoverflow.com/questions/10890261/how-to-match-a-emoticon-in-sentence-with-regular-expressions) to get rid of these, though I have not currently tested it. Technically, everything (including segmenting) still works with the emojis in, but it creates a lot of encoding errors down the line.

## Cleaning
Note that URLs need to be removed before segmenting.
### Stopwords
Use the stopwords from this [Baidu SEO guide](http://www.baiduguide.com/baidu-stopwords/). I don't know the organization, but the stopwords seem right. Code for getting the words is in **createStopwords.py**. Actual stopwords are in **stopwords.txt**.

## Creating tweet meta features
To create the features of tweet metadata, run the `createFeatures` function in **getTweets.py**. The function will generate feature vectors for the Weibo data provided. These features will be generated using *only* the training set. The resulting features vector will have 6 columns:

1. The proportion of the user's tweets that have been censored.
2. The number of times the user has been retweeted.
3. The number of times the tweet has been retweeted.
4. The proportion of tweets that were censored that day.
5. The proportion of the retweeted user's tweets that have been censored, if the tweet is a retweet.
6. The number of times that a retweeted message has been censored (for our training set, this will always be 0).

## Word Cloud
![Word cloud of censored tweets](https://github.com/brtsay/CSE190_Assignment2/blob/master/wc.png)

The last task (if there's time) is to get an English version of the word cloud. Also to compare the censored tweets with the non-censored tweets. "Sparta" is a reference to 十八大, the 18th Party Congress. They are almost homophones in Mandarin.

## Writeup
To get the **assignment2writeup.tex** file to compile, you need the [ACM style file](http://www.acm.org/publications/article-templates/sig-alternate-05-2015.cls) and the [ACM copyright file](http://www.acm.org/publications/article-templates/acmcopyright.sty). I just put these in the same directory as the **assignment2writeup.tex**.
