#!/usr/local/bin/perl
# Remove a MySQL clone module, or change the default

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'newmysqls_ecannot'});
&ReadParse();
&licence_status();
&error_setup($in{'default'} ? $text{'newmysqls_derr2'}
			    : $text{'newmysqls_derr'});
my @d = split(/\0/, $in{'d'});
@d || &error($text{'newmysqls_enone'});
my @mymods = (&list_remote_mysql_modules(), &list_remote_postgres_modules());

if ($in{'default'}) {
	# Just change the default for this DB type
	@d == 1 || &error($text{'newmysqls_etoomany'});

	# Set the default flag on the selected module
	my $newdef;
	foreach my $m (@mymods) {
		if ($m->{'minfo'}->{'dir'} eq $d[0]) {
			$newdef = $m;
			$m->{'config'}->{'virtualmin_default'} = 1;
			&save_module_config(
				$m->{'config'}, $m->{'minfo'}->{'dir'});
			}
		}

	# Clear the default flag on all others of the same type
	foreach my $m (@mymods) {
		if ($newdef &&
		    $m->{'minfo'}->{'dir'} ne $d[0] &&
		    $m->{'dbtype'} eq $newdef->{'dbtype'} &&
		    $m->{'config'}->{'virtualmin_default'}) {
			$m->{'config'}->{'virtualmin_default'} = 0;
			&save_module_config(
				$m->{'config'}, $m->{'minfo'}->{'dir'});
			}
		}
	if ($newdef) {
		&webmin_log("default", "newmysql",
			    $newdef->{'host'} || $newdef->{'sock'}, $newdef);
		}
	}
else {
	# Build and validate list to remove
	my %modmap = map { $_->{'minfo'}->{'dir'}, $_ } @mymods;
	my @alldoms = &list_domains();
	my @del;
	foreach my $d (@d) {
		my $mm = $modmap{$d};
		$mm || &error($text{'newmysqls_egone'});
		$mm->{'minfo'}->{'cloneof'} ||
			&error($text{'newmysqls_edelete'});
		$mm->{'config'}->{'virtualmin_default'} &&
			&error($text{'newmysqls_edefault'});
		$mm->{'config'}->{'virtualmin_provision'} &&
			&error($text{'newmysqls_eprovision'});
		my $modkey = $mm->{'dbtype'}.'_module';
		my @doms = grep { $_->{$modkey} eq
			          $mm->{'minfo'}->{'dir'} } @alldoms;
		@doms == 0 || &error(&text('newmysqls_einuse', scalar(@doms)));
		push(@del, $mm);
		}

	# Delete them
	foreach my $mm (@del) {
		if ($mm->{'dbtype'} eq 'mysql') {
			&delete_remote_mysql_module($mm);
			}
		else {
			&delete_remote_postgres_module($mm);
			}
		}

	&webmin_log("delete", "newmysqls", scalar(@d));
	}
&redirect("edit_newmysqls.cgi");
