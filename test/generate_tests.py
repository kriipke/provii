#!/usr/bin/env python3

import os
import sys

import jinja2


def generate_bats_tests(path='provii.bats.j2'):
    templateLoader = jinja2.FileSystemLoader(searchpath="./")
    templateEnv = jinja2.Environment(loader=templateLoader)

    t = templateEnv.get_template(path)
    with open('provii.bats', 'w') as f:
        print(t.render(allUtilities=os.listdir('../installs')), file=f)

generate_bats_tests('provii.bats.j2')
