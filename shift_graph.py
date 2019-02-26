#!/usr/bin/env python
"""Shift graph indexes.

Usage:
  shift_graph.py [options] <infile>
  shift_graph.py (-h | --help)
  shift_graph.py --version

Options:
  --only-id                         Input files has only ids.
  -d, --in-delimiter DELIMITER      Input delimiter [default: \t].
  -D, --out-delimiter DELIMITER     Output delimiter [default: \t].
  -h --help                         Show this screen.
  --version                         Show version.
"""
from docopt import docopt
import csv

if __name__ == '__main__':
    arguments = docopt(__doc__, version='shift_graph 0.2')

    infile = arguments['<infile>']
    in_delimiter = arguments['--in-delimiter']
    out_delimiter = arguments['--out-delimiter']
    only_id = arguments['--only-id']

    nodemap = dict()
    nodeid = 0

    lang = infile.split('.')[0]
    adate = infile.split('.')[2]
    outfile = ('{lang}.wikilink_graph.shift.{adate}.csv'
               .format(lang=lang,adate=adate)
               )
    oidfile = ('{lang}.wikilink_graph.{adate}.onlyid.csv'
               .format(lang=lang,adate=adate)
               )
    mapfile = ('{lang}.wikilink_graph.shift-map.{adate}.csv'
               .format(lang=lang,adate=adate)
               )

    is_header = True
    with open(infile, 'r') as infp:
        reader = csv.reader(infp, delimiter=in_delimiter)

        with open(outfile, 'w+') as outfp:
            with open(oidfile, 'w+') as oidfp:
                outwriter = csv.writer(outfp, delimiter=out_delimiter)
                oidwriter = csv.writer(oidfp, delimiter=out_delimiter)
                for line in reader:

                    if only_id:
                        sourceid = line[0]
                        targetid = line[1]
                    else:
                        sourceid = line[0]
                        sourcetitle = line[1]
                        targetid = line[2]
                        targettitle = line[3]

                    if is_header:
                        outwriter.writerow([sourceid, targetid])
                        oidwriter.writerow([sourceid, targetid])
                        is_header = False
                        continue

                    sourceid = int(sourceid)
                    targetid = int(targetid)
                    shiftsourceid = -1
                    shifttargetid = -1

                    if sourceid not in nodemap:
                        shiftsourceid = nodeid
                        nodemap[sourceid] = nodeid
                        nodeid = nodeid + 1
                    else:
                        shiftsourceid = nodemap[sourceid]

                    if targetid not in nodemap:
                        shifttargetid = nodeid
                        nodemap[targetid] = nodeid
                        nodeid = nodeid + 1
                    else:
                        shifttargetid = nodemap[targetid]

                    outwriter.writerow([shiftsourceid, shifttargetid])
                    oidwriter.writerow([sourceid, targetid])


    with open(mapfile, 'w+') as mapfp:
        mapwriter = csv.writer(mapfp, delimiter='\t')
        mapwriter.writerow(['original_id', 'shift_id'])
        for orig in sorted(nodemap.keys()):
            shift = nodemap[orig]
            mapwriter.writerow([orig, shift])

    exit(0)
