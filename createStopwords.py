import requests
from lxml import html

# get stopword page from baidu
page = requests.get('http://www.baiduguide.com/baidu-stopwords/')

# get relevant text
tree = html.fromstring(page.content)
stopwords = tree.xpath('//div[@class = "entry-content clearfix"]/p/text()')
# get rid of first two elements (description)
del(stopwords[0:2])
# and last two elements (??)
del(stopwords[-2:])
# join list first (not sure if necessary)
stopwords = ','.join(stopwords)
# some have double commas
stopwords.replace(',,', ',')
# return to list of strings
stopwords = stopwords.split(',')
# get rid of spaces
stopwords = [word.replace(' ', '') for word in stopwords]
# get rid of newline character
stopwords = [word.replace('\n', '') for word in stopwords]
# get rid of blanks
stopwords = [word for word in stopwords if word != '' if word != ' ']

# write out
with open("stopwords.txt", 'w') as fn:
    for item in stopwords:
        fn.write("%s\n" % item)

