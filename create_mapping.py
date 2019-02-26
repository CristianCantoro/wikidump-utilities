#!/usr/bin/env python3
"""

Example:
    ./create_mapping.py --oldmap 
                        -g wikilink_graph.2005-12-15.csv 
                        -s snapshot.2005-12-15.csv
                        2005-12-15 en

"""

import sys
import csv
import pathlib
import argparse
import collections
import operator
from datetime import datetime


def valid_date(date_str):

    # define function to parse 3 different date formats
    def parse_date(date_str):


        for fmt in ('%Y-%m-%d', '%d.%m.%Y', '%d/%m/%Y'):
            try:
                return datetime.strptime(date_str, fmt)
            except ValueError:
                pass

        raise ValueError('No valid date format found')
        return

    # try parse the date or handle the error and produce an error message
    try:
        date = parse_date(date_str)
    except ValueError:
        msg = ("Not a valid date: '{0}', allowed formats: " + \
               "'Y-m-d', 'd.m.Y', 'd/m/Y'.").format(s)
        raise argparse.ArgumentTypeError(msg)

    return date


# How do you remove duplicates from a list whilst preserving order?
# https://stackoverflow.com/a/480227/2377454
def uniqfy_list(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]


if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('date',
                        type=valid_date,
                        help='Reference date, used for file names.')
    parser.add_argument('lang',
                        type=str,
                        help='Two-letter language code.')
    parser.add_argument('--graph-delimiter',
                        type=str,
                        default=' ',
                        help="Graph file delimiter [default: ' '].")
    parser.add_argument('--snapshot-delimiter',
                        type=str,
                        default=',',
                        help="Snapshot file delimiter [default: ','].")
    parser.add_argument('--map',
                        action='store_true',
                        help='Create a file with old and new ids.')
    parser.add_argument('--name',
                        action='store_true',
                        help='Create a file with the graph with names.')
    parser.add_argument('-o', '--output',
                        type=pathlib.Path,
                        help='Output file name [default: stdout].')
    parser.add_argument('--oldmap',
                        action='store_true',
                        help='Create oldmap')
    parser.add_argument('-g', '--graph',
                        type=pathlib.Path,
                        required=True,
                        help='Wikilink graph file.')
    parser.add_argument('-s', '--snapshot',
                        type=pathlib.Path,
                        required=True,
                        help='Snapshot file.')
    parser.add_argument('--skip-graph-header',
                        action='store_true',
                        help='Skip graph file header.')
    parser.add_argument('--skip-snapshot-header',
                        action='store_true',
                        help='Skip snapshot file header')
    args = parser.parse_args()

    date = args.date
    lang = args.lang

    graphfile = args.graph.open('r')
    snapshotfile = args.snapshot.open('r')

    outfile = None
    if args.output is None:
        outfile = sys.stdout
    else:
        outfile = output.open('w+')

    graphreader = csv.reader(graphfile, delimiter=args.graph_delimiter)
    snapshotreader = csv.reader(snapshotfile, delimiter=args.snapshot_delimiter)
    if args.skip_graph_header:
        next(graphreader)
    if args.skip_snapshot_header:
        next(snapshotreader)

    graph = uniqfy_list(((int(e[0]),int(e[1])) for e in graphreader))
    graph_numedges = len(graph)
    graph_numnodes = len(set([node for edge in graph
                              for node in edge])) + 1

    tmpsnap = [(int(line[0]), line[1])
               for line in snapshotreader]
    dsnap = dict(tmpsnap)
    assert len(tmpsnap) == len(dsnap)
    del tmpsnap

    odsnap = collections.OrderedDict(sorted(dsnap.items()))
    assert len(dsnap) == len(odsnap)
    del dsnap

    enodsnap = enumerate(odsnap)

    idmap = dict()
    for newid, oldid in enodsnap:
        idmap[oldid] = newid

    imfname = '{}wiki.idmap_o2n.{}.csv'.format(lang,
                                               date.strftime('%Y-%m-%d')
                                               )
    with open(imfname, 'w+') as idmapfile:
        idmap_csv = csv.writer(idmapfile, delimiter=' ')

        for oid, nid in idmap.items():
            idmap_csv.writerow((oid, nid))

    gsfname = '{}wiki.wikigraph.shift.{}.csv'.format(lang,
                                                     date.strftime('%Y-%m-%d')
                                                     )
    with open(gsfname, 'w+') as graphshiftfile:
        graphshift = csv.writer(graphshiftfile, delimiter='\t')

        for oid1, oid2 in graph:
            try:
                nid1 = idmap[oid1]
                nid2 = idmap[oid2]
            except KeyError as err:
                print("Error: old id nodes ({}, {}) not found."
                      .format(oid1, oid2),
                      file=sys.stderr)
                continue

            graphshift.writerow((nid1, nid2))

    prname = '{}wiki.wikigraph.pagerank.{}.csv'.format(lang,
                                                    date.strftime('%Y-%m-%d')
                                                    )
    with open(prname, 'w+') as pagerankfile:
        pagerank = csv.writer(pagerankfile, delimiter=' ')
        with open(gsfname, 'r') as graphshiftfile:
            graphshift = csv.reader(graphshiftfile, delimiter='\t')
            shift = [(int(e1), int(e2)) for e1, e2 in graphshift]
            shift_numedges = len(shift)
            shift_numnodes = len(set([node for edge in graph
                                      for node in edge])) + 1

            assert graph_numedges == shift_numedges
            assert graph_numnodes == shift_numnodes
            pagerank.writerow((shift_numedges, shift_numnodes))

        with open(gsfname, 'r') as graphshiftfile:
            graphshift = csv.reader(graphshiftfile, delimiter='\t')
            for l1, l2 in graphshift:
                pagerank.writerow((l1, l1))


    nodsnap = dict()
    nsfname = '{}wiki.wikigraph.snapshot.{}.csv'.format(lang,
                                                        date.strftime('%Y-%m-%d')
                                                        )
    with open(nsfname, 'w+') as newsnapshotfile:
        newsnapshot = csv.writer(newsnapshotfile, delimiter='\t')

        for oid, v in odsnap.items():
            nid = idmap[oid]

            nodsnap[nid] = v
            newsnapshot.writerow((nid, v))

    if args.name:
        tmpsl = set()
        newtmpsl = set()
        ssfname = '{}wiki.wikigraph.name.{}.csv'.format(lang,
                                                        date.strftime('%Y-%m-%d')
                                                        )
        with open(ssfname , 'w+') as snapshotnamefile:
            snapshotname = csv.writer(snapshotnamefile, delimiter='\t')

            for e1, e2 in graph:
                en1 = odsnap[e1]
                en2 = odsnap[e2]

                ne1 = idmap[e1]
                ne2 = idmap[e2]

                nen1 = nodsnap[ne1]
                nen2 = nodsnap[ne2]

                tmpsl.add((en1, en2))
                newtmpsl.add((nen1, nen2))

                snapshotname.writerow((en1, en2))

        assert tmpsl == newtmpsl
        del tmpsl
        del newtmpsl

    if args.oldmap:
        newcounter = 0
        idmap_o2n = dict()

        for e1, e2 in graph:
            if e1 not in idmap_o2n:
                idmap_o2n[e1] = newcounter
                newcounter = newcounter + 1

            if e2 not in idmap_o2n:
                idmap_o2n[e2] = newcounter
                newcounter = newcounter + 1

        omgfname = '{}wiki.oldmap.{}.csv'.format(lang,
                                                 date.strftime('%Y-%m-%d')
                                                 )
        with open(omgfname, 'w+') as oldmapgraphfile:
            oldmapgraph = csv.writer(oldmapgraphfile, delimiter='\t')

            newgraph = [(idmap_o2n[e1], idmap_o2n[e2])
                        for e1, e2 in graph]

            for ne1, ne2 in sorted(newgraph, key=operator.itemgetter(0, 1)):
                oldmapgraph.writerow((ne1, ne2))

    exit(0)
