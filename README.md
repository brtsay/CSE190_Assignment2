# CSE190 Assignment 2

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
Use the stopwords from [Baidu](http://www.baiduguide.com/baidu-stopwords/). Code for getting the words is in **createStopwords.py**. Actual stopwords are in **stopwords.txt**.

## Word Cloud
![Word cloud of censored tweets](https://github.com/brtsay/CSE190_Assignment2/blob/master/wordcloud_cens.png)

The last task (if there's time) is to get an English version of the word cloud. Also to compare the censored tweets with the non-censored tweets. "Sparta" is a reference to 十八大, the 18th Party Congress. They are almost homophones in Mandarin.
