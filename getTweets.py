#!/usr/bin/python
# -*- coding: utf-8 -*-

import csv
import random
import numpy as np
import os
import glob
import zipfile
import StringIO
import sys
import re
from collections import defaultdict

def extractTweets(write_dir, desired_tweets):
    """
    Creates set of censored and noncensored tweets.

    Will write out two CSV files: one that has all censored tweets
    and the other all noncensored tweets.

    Args:
        write_dir: A string that tells the function where to write
            the files.
        desired_tweets: An integer that indicates the rough number
            of desired noncensored tweets.

    Returns:
        Nothing. Will simply write out two CSV files.
    """
    csv.field_size_limit(sys.maxsize)
    os.chdir(write_dir)
    tweetDir = '/mainstorage/data/weibo/week*.zip'
    censored = []
    n_censored = []
    prop = float(desired_tweets)/226841122
    for name in glob.glob(tweetDir):
        base = os.path.basename(name)  # get name of path
        filename = os.path.splitext(base)[0]  # split into filename and extension, keeping only filename
        dataDir = '/mainstorage/data/weibo/'
        dataFile = filename
        archive = '.'.join([dataFile, 'zip']) # merge filename and the '.zip' extension together
        fullPath = ''.join([dataDir, archive]) # merge path together with where it's located to get full path
        csvFile = '.'.join([dataFile, 'csv']) # add the extension '.csv' to the filename
        fileHandle = open(fullPath, 'rb')
        zFile = zipfile.ZipFile(fileHandle)
        data = StringIO.StringIO(zFile.read(csvFile))
        reader = csv.reader(data)
        headers = reader.next()  # get out headers
        headers.append('week') # add the week to headers
        print('Now going through', dataFile)
        censored_count = 0
        n_censored_count = 0
        row_count = 0
        week = int(re.search(r'\d+', dataFile).group())
        for row in reader:
            row_count += 1
            if row[10].strip():            # see if permission_denied
                new_row = [row, [week]]
                new_row = [item for sublist in new_row for item in sublist]
                censored.append(new_row)
                censored_count += 1
            elif random.uniform(1, 226841122) < desired_tweets:    # get random subset
                new_row = [row, [week]]
                new_row = [item for sublist in new_row for item in sublist]
                n_censored.append(new_row)
                n_censored_count += 1
        print('Extracted', n_censored_count, 'uncensored tweets')
        print('Extracted', censored_count, 'censored tweets')
    with open('censoredTweets.csv', 'wb') as csvfile:
        writer = csv.writer(csvfile, delimiter = ',')
        writer.writerow(headers)
        for tweet in censored:
            writer.writerow(tweet)
    with open('noncensoredTweets.csv', 'wb') as csvfile:
        writer = csv.writer(csvfile, delimiter = ',')
        writer.writerow(headers)
        for tweet in n_censored:
            writer.writerow(tweet)

def userDict(userdata, uid_list):
    """
    Generates dictionary with user attributes.

    This function will create dictionary where the UID is the key and
    has the province, gender, and verified status as values.

    Args:
        userdata: A string that provides the path to userdata.zip
        uid_list: A list of the desired UIDs (train, valid, test).

    Returns:
        A dictionary with UID keys and province, gender, and verified
        values.
    """
    zfile = zipfile.ZipFile(userdata)
    data = StringIO.StringIO(zfile.read('userdata.csv'))
    reader = csv.DictReader(data)
    user_dict = dict()
    for uid in uid_list:
        if uid not in user_dict:
            for row in reader:
                if row['uid'] == uid:
                    user_dict[row['uid']] = {'province': row['province'], 'gender': row['gender'], 'verified': row['verified']}
                    break
    return(user_dict)


def censoredDict(train_data):
    """
    Gets number of censored tweets by user.

    Args:
        tweets: A string that indicates the path to the file with 
            the training data.

    Returns:
        A dictionary that says how many times a user's tweet has
        been censored in the training data.
    """
    with open(train_data, 'rb') as f:
        all_data = [row for row in f]
    cen_uid = defaultdict(int)
    for obs in all_data:
        if obs.decode('latin-1').split(',')[10].strip():
            uid = obs.decode('latin-1').split(',')[2]
            try:
                cen_uid[uid] += 1
            except KeyError:
                cen_uid[uid] = 1
    return(cen_uid)



