#!/usr/bin/env python
"""
usage: set_pbs_options_hpc.py [-h] [-i | -o OUTPUT] SCRIPT {pbs} ...

Show and set PBS options for SCRIPT.

positional arguments:
  SCRIPT                Script where to show or set PBS options.
  {pbs}
    pbs                 Set pbs options.

optional arguments:
  -h, --help            show this help message and exit
  -i, --inplace         Modify the input file in-place.
  -o OUTPUT, --output OUTPUT
                        Output file.

example: ./set_pbs_options_hpc.py job_hpc.sh


Subcommand `pbs`:

usage: set_pbs_options_hpc.py SCRIPT pbs [-h] [-c PBS.NCPUS] [-n PBS.NODES]
                                         [-w PBS.WALLTIME]

optional arguments:
  -h, --help            show this help message and exit
  -c PBS.NCPUS, --ncpus PBS.NCPUS
                        Number of cpus to request.
  -n PBS.NODES, --nodes PBS.NODES
                        Number of nodes to request.
  -p PBS.PROCPERNODE, --procpernode PBS.PROCPERNODE
                        Number of processes to allocate for each node.
  -w PBS.WALLTIME, --walltime PBS.WALLTIME
                        Max walltime for the job, a time period formatted as
                        hh:mm:ss.
"""

import sys
import argparse
import pathlib
from string import Template
from datetime import timedelta

# argparse subcommands with nested namespaces
# https://stackoverflow.com/a/18709860/2377454
class NestedNamespace(argparse.Namespace):
    def __setattr__(self, name, value):
        if '.' in name:
            group,name = name.split('.',1)
            ns = getattr(self, group, NestedNamespace())
            setattr(ns, name, value)
            self.__dict__[group] = ns
        else:
            self.__dict__[name] = value


# Formatting python timedelta objects
# https://stackoverflow.com/a/30536361/2377454
class DeltaTemplate(Template):
    delimiter = ''


def strfdelta(tdelta, fmt='hh:mm:ss'):
    d = dict()

    hours, rem = divmod(tdelta.seconds, 3600)
    minutes, seconds = divmod(rem, 60)

    hours = tdelta.days * 24

    d['hh'] = '{:02d}'.format(hours)
    d['mm'] = '{:02d}'.format(minutes)
    d['ss'] = '{:02d}'.format(seconds)

    t = DeltaTemplate(fmt)
    return t.substitute(**d)


def positive_int(value):
    ivalue = int(value)

    if ivalue <= 0:
        errmsg = "{} is an invalid positive int value"
        raise argparse.ArgumentTypeError(errmsg.format(value))

    return ivalue


def time_period(value):

    try:
        periods = value.split(':', 2)

        hours = int(periods[0])
        minutes = int(periods[1])
        seconds = int(periods[2])
    except:
        errmsg = "{} is an time period. It must be in the format hh:mm:ss."
        raise argparse.ArgumentTypeError(errmsg.format(value))

    tdelta = timedelta(hours=hours, minutes=minutes, seconds=seconds)

    return strfdelta(tdelta)


def cli_args():
    parser = argparse.ArgumentParser(
        prog='set_pbs_options_hpc.py',
        description='Show and set PBS options for SCRIPT.',
        epilog='example: ./set_pbs_options_hpc.py job_hpc.sh'
        )
    parser.add_argument("SCRIPT",
                        type=pathlib.Path,
                        help="Script where to show or set PBS options.",
                        )
    outgroup = parser.add_mutually_exclusive_group()
    outgroup.add_argument("-i", "--inplace",
                          action='store_true',
                          help="Modify the input file in-place."
                          )
    outgroup.add_argument("-o", "--output",
                          type=pathlib.Path,
                          help="Output file."
                          )
    outgroup.add_argument("-p", "--only-pbs",
                          action='store_true',
                          help="Print only pbs options."
                          )

    subparsers = parser.add_subparsers(dest="command")

    pbsparser = subparsers.add_parser('pbs',
                                      help='Set pbs options.',
                                      )
    pbsparser.add_argument("-c", "--ncpus",
                           dest='pbs.ncpus',
                           type=positive_int,
                           help="Number of cpus to request.",
                           )
    pbsparser.add_argument("-n", "--nodes",
                           dest='pbs.nodes',
                           type=positive_int,
                           help="Number of nodes to request.",
                           )
    pbsparser.add_argument("-p", "--procpernode",
                           dest='pbs.procpernode',
                           type=positive_int,
                           help="Number of processes to allocate for each node.",
                           )
    pbsparser.add_argument("-w", "--walltime",
                           dest='pbs.walltime',
                           type=time_period,
                           help="Max walltime for the job, a time period "
                                "formatted as hh:mm:ss.",
                           )

    nns = NestedNamespace()
    args = parser.parse_args(namespace=nns)

    return args


def split_l_option(option, line):
    line = line.replace('-l', '').strip()

    value = None
    if option in ('select'):
        splitline = line.split(':')

        select_value = int([line for line in splitline
                            if option in line][0].split('=')[-1])
        value = {'select': select_value}

        properties = dict(prop.split('=') for prop in splitline[1:])
        value.update(properties)

    elif option in ('walltime'):
         value = line.split('=')[-1]

    return {option: value}


def read_pbs_opts(pbs_lines):
    optdict = dict()
    for line in pbs_lines:
        if line.startswith('-V'):
            optdict['-V'] = line.replace('-V', '').strip()

        if line.startswith('-l'):

            if optdict.get('-l', None) is None:
                optdict['-l'] = dict()

            if 'select' in line:
                optdict['-l'].update(split_l_option('select', line))
            if 'walltime' in line:
                optdict['-l'].update(split_l_option('walltime', line))

        if line.startswith('-q'):
            optdict['-q'] = line.replace('-q', '').strip()

    return optdict


def write_pbs_opts(optdict, output):
    for opt, value in optdict.items():
        if opt == '-l':
            resdict = optdict['-l']
            if 'walltime' in resdict:
                print("#PBS -l walltime={walltime}"
                      .format(walltime=resdict['walltime']),
                      file=output
                      )
                del resdict['walltime']

            if len(resdict) > 0:
                resstr = ''
                for resname, resvalue in resdict.items():
                    if isinstance(resvalue, dict):
                        propstr = ''
                        for propname, propvalue in resvalue.items():
                            propstr += ("{propname}={propvalue}:"
                                       .format(propname=propname, propvalue=propvalue)
                                       )
                        propstr = propstr.strip().rstrip(':')
                        resstr = propstr
                    else:
                        resstr += ("{resname}={resvalue},"
                                   .format(resname=resname, resvalue=resvalue)
                                   )
                    
                resstr = resstr.strip().rstrip(',')
                print("#PBS -l {}".format(resstr),
                      file=output
                      )

        else:
            print("#PBS {opt} {value}".format(opt=opt, value=value).strip(),
                  file=output
                  )


def main():
    args = cli_args()

    scriptfile = args.SCRIPT

    pbs_lines = []
    other_lines = []
    pre_lines = []

    pre_pbs = True
    with scriptfile.open('r') as sfp:
        for line in sfp.readlines():
            if not line.startswith('#PBS') and pre_pbs:
                pre_lines.append(line.strip())
            elif line.startswith('#PBS'):
                pre_pbs = False
                pbs_lines.append(line.strip().replace('#PBS ', ''))
            else:
                other_lines.append(line.strip())

    optdict = read_pbs_opts(pbs_lines)

    if args.command == 'pbs':
        if args.pbs.ncpus:
            optdict['-l']['select']['ncpus'] = args.pbs.ncpus
        if args.pbs.procpernode:
            optdict['-l']['select']['ppn'] = args.pbs.procpernode
        if args.pbs.nodes:
            optdict['-l']['select']['select'] = args.pbs.nodes
        if args.pbs.walltime:
            optdict['-l']['walltime'] = args.pbs.walltime

    outfile = None
    if args.output is None and not args.inplace:
        outfile = sys.stdout
    elif args.inplace:
        outfile = scriptfile.open('w+')
    else:
        outfile = args.output.open('w+')

    if not args.only_pbs:
        for line in pre_lines:
            print(line, file=outfile)
 
    write_pbs_opts(optdict, outfile)
 
    if not args.only_pbs:
        for line in other_lines:
            print(line, file=outfile)


if __name__ == '__main__':
    main()

    exit(0)
