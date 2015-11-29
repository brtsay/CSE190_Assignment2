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

def userDict(userdata, uid_path):
    """
    Generates dictionary with user attributes.

    This function will create dictionary where the UID is the key and
    has the province, gender, and verified status as values.

    Args:
        userdata: A string that provides the path to userdata.zip
        uid_path: A string that provides the path to a list of
            UIDs (train).

    Returns:
        A dictionary with UID keys and province, gender, and verified
        values.
    """
    with open(uid_path) as f:
        reader = csv.reader(f)
        next(reader, None)                     # get rid of header
        uid_list = [uid for uid in reader]
    uid_list = [item for sublist in uid_list for item in sublist]
    user_dict = dict()
    for uid in uid_list:
        zfile = zipfile.ZipFile(userdata)
        data = StringIO.StringIO(zfile.read('userdata.csv'))
        reader = csv.DictReader(data)
        for row in reader:
            if row['uid'] == uid:
                user_dict[row['uid']] = {'province': row['province'], 'gender': row['gender'], 'verified': row['verified']}
                print(len(user_dict))
                break
    return(user_dict)

def metaDict(train_data):
    """
    Creates dictionaries about users, messages, and the day.

    This will create five dictionaries that measure how many times
    the user/message have been censored and the popularity of users
    and messages. Also measures what proportion of tweets per day
    are censored.

    Args:
        train_data: A string that indicates the path to the file 
            with the training data.
 
    Returns:
        cen_uid: The first measures how many times a user has been 
            censored. 
        cen_mid: The second measures how many times a message has 
            been censored. In theory, everything should be a 1. 
        cen_re_uid: The third measures how many times a user has been
            retweeted. 
        cen_re_mid: The fourth measures how many times a message has
            been retweeted. 
        day_dict: The fifth has another dictionary inside which
            measure the total number of tweets that day and the 
            number of tweets that day that had been censored.

    Dictionaries might have to be accessed by dict[u'"key"']. 
    """
    with open(train_data, 'rb') as f:
        all_data = [row for row in f]
    cen_uid = defaultdict(int)
    cen_mid = defaultdict(int)
    cen_re_uid = defaultdict(int)
    cen_re_mid = defaultdict(int)
    day_dict = defaultdict(dict)
    for obs in all_data:
        re_mid = obs.decode('latin-1').split(',')[1]
        if re_mid.strip():
            try:
                cen_re_mid[re_mid] += 1
            except KeyError:
                cen_re_mid[re_mid] = 1
        re_uid = obs.decode('latin-1').split(',')[3]
        if re_uid.strip():
            try:
                cen_re_uid[re_uid] += 1
            except KeyError:
                cen_re_uid[re_uid] = 1
        day = obs.decode('latin-1').split(',')[7].split(' ')[0].replace('"', '')
        try:
            day_dict[day]['total'] += 1
        except KeyError:
            day_dict[day]['total'] = 1
        # 9 refers to the permission_denied column
        if obs.decode('latin-1').split(',')[9] == "TRUE":
            uid = obs.decode('latin-1').split(',')[2]
            try:
                cen_uid[uid] += 1
            except KeyError:
                cen_uid[uid] = 1
            mid = obs.decode('latin-1').split(',')[0]
            try:
                # in theory this should never be triggered
                cen_mid[mid] += 1
            except KeyError:
                cen_mid[mid] = 1
            try:
                day_dict[day]['cens'] += 1
            except KeyError:
                day_dict[day]['cens'] = 1
    return(cen_uid, cen_mid, cen_re_uid, cen_re_mid, day_dict)

def createFeatures(data_path, train_path):
    """
    Creates feature vector for prediction

    Args:
        data_path: A string that indicates what data to create a
            feature vector for.
        train_path: A string that indicates the path to the training
            data. This is used for creating the dictionaries.

    Returns:
        A vector of features that indicate the number of times a user
        has been censored, the number of times the retweeted user has
        been censored and the number of times a retweeted message 
        has been censored (if the tweet is a retweet). Also has the
        proportion of tweets that have been censored that day.
    """
    cen_uid, cen_mid, cen_re_uid, cen_re_mid, day_dict = metaDict(train_path)
    # with open(user_attr_path, 'rb') as f:
    #     reader = csv.reader(f)
    #     user_attr = dict(reader)
    with open(data_path, 'rb') as f:
        header = next(f)
        data = [row for row in f]
    # 0: num times user has been censored
    # 1: num times retweeted user has been censored
    # 2: num times retweeted message has been censored
    # 3: proportion of tweets censored that day
    features = []
    for obs in data:
        uid = obs.decode('latin-1').split(',')[2]
        re_uid = obs.decode('latin-1').split(',')[3]
        re_mid = obs.decode('latin-1').split(',')[1]
        day = obs.decode('latin-1').split(',')[7].split(' ')[0].replace('"', '')
        cens_ruid = 0 if re_uid=='""' else cen_re_uid[re_uid]
        cens_rmid = 0 if re_mid=='""' else cen_re_mid[re_mid]
        try:
            day_prop = day_dict[day]['cens']/day_dict[day]['total']
        except KeyError:
            day_prop = 0
        features.append([cen_uid[uid], cens_ruid, cens_rmid, day_prop])
    return(features)
        
with open("/home/b/Documents/CSE190_Data/test_feat.csv", 'w') as f:
    writer = csv.writer(f)
    for item in a:
        writer.writerow(item)

