#!/usr/bin/env python
"""Shift graph indexes.

Usage:
  shift_graph.py <infile>
  shift_graph.py (-h | --help)
  shift_graph.py --version

Options:
  -h --help     Show this screen.
  --version     Show version.
"""
from docopt import docopt
import csv

if __name__ == '__main__':
    arguments = docopt(__doc__, version='shift_graph 0.1')
    
    infile = arguments['<infile>']

    nodemap = dict()
    nodeid = 0

    adate = infile.split('.')[1]
    outfile = 'wikilink_graph.shift.{}.csv'.format(adate)
    mapfile = 'wikilink_graph.shift-map.{}.csv'.format(adate)

    with open(infile, 'r') as infp:
        with open(outfile, 'w+') as outfp:
            writer = csv.writer(outfp,delimiter='\t')
            for line in infp.readlines():
                source, target = line.strip().split()

                source = int(source)
                target = int(target)
                shiftsource = -1
                shifttarget = -1

                if source not in nodemap:
                    shiftsource = nodeid
                    nodemap[source] = nodeid
                    nodeid = nodeid + 1
                else:
                    shiftsource = nodemap[source]

                if target not in nodemap:
                    shifttarget = nodeid
                    nodemap[target] = nodeid
                    nodeid = nodeid + 1
                else:
                    shifttarget = nodemap[target]

                writer.writerow([shiftsource, shifttarget])

    with open(mapfile, 'w+') as mapfp:
        mapwriter = csv.writer(mapfp, delimiter='\t')
        mapwriter.writerow(['original_id', 'shift_id'])
        for orig in sorted(nodemap.keys()):
            shift = nodemap[orig]
            mapwriter.writerow([orig, shift])

    exit(0)