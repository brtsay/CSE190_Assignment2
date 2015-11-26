# CSE190 Assignment 2

## Segmenting the data
Use the [Stanford Word Segmenter](http://nlp.stanford.edu/software/segmenter.shtml). Unzip then run the following command from terminal:
```bash
segment.sh ctb [filepath] UTF-8 0 > [new filename]
```

## Cleaning
Note that URLs need to be removed before segmenting.
### Stopwords
Use the stopwords from [Baidu](http://www.baiduguide.com/baidu-stopwords/). Code for getting the words is in **createStopwords.py**. Actual stopwords are in **stopwords.txt**.


