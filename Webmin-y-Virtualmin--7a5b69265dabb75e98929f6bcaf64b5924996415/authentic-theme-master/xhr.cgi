#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in);

do($root_directory/$current_theme . "/authentic-lib.pl");
do($root_directory/$current_theme . "/xhr-lib.pl");

xhr();
