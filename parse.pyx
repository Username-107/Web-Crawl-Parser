from json import loads
from csv import writer
from time import time
import cython
start = time()

STARTING_ROW: cython.int
JUMP: cython.int
done: cython.int
i: cython.int

STARTING_ROW, JUMP = 44, 32

# ASCII ID for less memory, from 33-126 (because of whitespace trimming), 
# skipping 22 and 92, comma and backslash (ex comma, between '-' and '+' on ASCII chart)
# uses much less memory with almost no added time
def increment(id):
    for i in range(len(id) - 1, -1, -1):
        x = id[i]
        if x != "~":
            return "".join([id[:i], ("-" if x == "+" else ("]" if x == "[" else chr(ord(x) + 1))), id[i+1:]])
        id = "".join([id[:i], "!", id[i+1:]])
    # new character
    return "".join(["!", id])

sites = writer(open("sites.csv", "w"))
links = writer(open("links.csv", "w"))

# headers

sites.writerow([":ID", "url", "title"]) 
# if a title is not known, it will be an empty string
# in the search engine, the url can be used, but doing that here takes much more space

links.writerow([":START_ID", ":END_ID"])
# written in IDs

done, id = 0, "!"

with open("TestData.wat", encoding="utf-8") as f:
    # set buffer, skip header
    for i in range(STARTING_ROW):
        f.__next__()

    try:
        while True:
            data = loads(f.readline())['Envelope']
            url = data['WARC-Header-Metadata']['WARC-Target-URI']
            try:
                title = data['Payload-Metadata']['HTTP-Response-Metadata']['HTML-Metadata']['Head']['Title']
                linkbook = data['Payload-Metadata']['HTTP-Response-Metadata']['HTML-Metadata']['Links']
                sites.writerow([id, url, title])
                curid = id
                id = increment(id)
                swrite = []
                lwrite = []
                for link in linkbook:
                    l = "" # the link
                    if "url" in link:
                        l = link["url"]
                    elif link:
                        # links always include "href" or "url" unless they are empty
                        l = link["href"]

                    if l[:4] == "http":
                        # this is a link to a site or image
                        # we need to make sure it gets included
                        # if it is a duplicate, that's ok, it'll get filtered
                        swrite.append([id, l, ""])
                        lwrite.append([curid, id])
                        id = increment(id)
                    elif l[0] == "/":
                        # a directory (ie /images)
                        swrite.append([id, "".join([url if url[-1] != "/" else url[:-1], l]), ""]) # also must be included, just in case (think stack overflow)
                        lwrite.append([curid, id])
                        id = increment(id)
                    # Anything else is somehting like javascript or php,
                    # which is not accessed by a search engine
                sites.writerows(swrite)
                links.writerows(lwrite)

            except:
                # site does not have HTML Metadata (no title, no links)
                sites.writerow([id, url, ""])
                id = increment(id)
            done += 1
            if done % 1000 == 0:
                print(str(done) + " sites loaded")
            for i in range(JUMP):
                f.__next__()
    except:
        #file ended
        pass
print(time()-start)