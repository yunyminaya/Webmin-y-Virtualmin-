#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;
use lib ($ENV{'LIBROOT'} . "/vendor_perl");
BEGIN {push(@INC, "..");}
use WebminCore;
init_config();
do($root_directory/$current_theme . "/authentic-funcs.pl");
do($root_directory/$current_theme . "/stats-lib-funcs.pl");

1;
