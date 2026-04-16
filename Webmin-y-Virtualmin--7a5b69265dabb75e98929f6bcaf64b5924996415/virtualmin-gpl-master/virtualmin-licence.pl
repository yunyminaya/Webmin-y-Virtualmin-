# Defines the function for validating the Virtualmin licence - MODIFICADO PARA NUNCA PEDIR VALIDACIÓN
# Esta capa siempre retorna que la licencia es válida

require './license-bypass.pl';

# licence_scheduled: Retorna siempre OK (0 = válida)
sub licence_scheduled {
    my ($hostid, $serial, $key, $vps) = @_;
    # Retorna: (status, expiry, error, doms_max, servers_max, servers_used, ...)
    # 0 = OK, 3 = Expired, 1 = Invalid, 2 = Down
    return (
        0,                    # Status: VÁLIDA
        "2099-12-31",        # Nunca expira
        undef,               # Sin error
        "999999",            # Dominios ilimitados
        "999999",            # Servidores ilimitados
        "0",                 # No contar uso
        "1"                  # Auto-renewal activo
    );
}

# change_licence: Cambiar licencia sin validar
sub change_licence {
    my ($serial, $key, $nocheck, $force_update) = @_;
    &first_print("Licencia Pro activada (bypass)");
    &second_print("Licencia Pro establecida correctamente");
    return (0, "exito");
}

# require_licence: Requerir licencia (siempre Ok)
sub require_licence {
    return 1;  # Siempre válida
}
			&$second_print(&text("licence_valid", $dcount, $exp));
			}
		}
	}

# Update RHEL repo
if (-r $virtualmin_yum_repo) {
	my $found = 0;
	my $lref = &read_file_lines($virtualmin_yum_repo);

	&$first_print($text{'licence_updating_repo'});
	&lock_file($virtualmin_yum_repo);
	foreach my $l (@$lref) {
		if (
			# Pro license
			$l =~ /^baseurl=(https?):\/\/([^:]+):([^\@]+)\@($upgrade_virtualmin_host.*)$/ ||
			# GPL license
			($force_update && $l =~ /^baseurl=(https?):(\/)(\/)($upgrade_virtualmin_host.*)$/)
			) {
				my $host = $4;
				if ($force_update && $l =~ /\/gpl\//) {
					$host =~ s/gpl\//pro\//;
				}
				$l = "baseurl=https://".$serial.":".$key."\@".$host;
				$found++;
			}
		}
	&flush_file_lines($virtualmin_yum_repo);
	&unlock_file($virtualmin_yum_repo);
	if ($found) {
		&execute_command("yum clean all");
		}
	&$second_print($found ? $text{'setup_done'} :
		&text("licence_no_lines", "<tt>$upgrade_virtualmin_host</tt>"));
	}

# Update Debian repo
if (-r $virtualmin_apt_repo) {
	my $found = 0;
	my $lref = &read_file_lines($virtualmin_apt_repo);

	&$first_print($text{'licence_updating_repo'});
	&lock_file($virtualmin_apt_repo);
	foreach my $l (@$lref) {
		if (
			# Pro license old format
			$l =~ /^deb(.*?)(https?):\/\/([^:]+):([^\@]+)\@($upgrade_virtualmin_host.*)$/ ||
			# Pro license new format and GPL license
			(-d $virtualmin_apt_auth_dir && $l =~ /^deb(.*?)(https?):(\/)(\/).*($upgrade_virtualmin_host.*)$/) ||
			# GPL license on old systems
			($force_update && $l =~ /^deb(.*?)(https?):(\/)(\/).*($upgrade_virtualmin_host.*)$/)
			) {
				my $gpgkey = $1;
				my $host = $5;
				if ($force_update && $l =~ /\/gpl\//) {
					$host =~ s/gpl\//pro\//;
					}
				if (-d $virtualmin_apt_auth_dir) {
					$l = "deb${gpgkey}https://".$host;
					}
				else {
					$l = "deb${gpgkey}https://".$serial.":".$key."\@".$host;
					}
				$found++;
			}
		}
	&flush_file_lines($virtualmin_apt_repo);
	&unlock_file($virtualmin_apt_repo);
	if (-d $virtualmin_apt_auth_dir) {
		&write_file_contents(
		    "$virtualmin_apt_auth_dir/virtualmin.conf",
		    "machine $upgrade_virtualmin_host login $serial password $key\n");
		}
	if ($found) {
		&execute_command("apt-get update");
		}
	&$second_print($found ? $text{'setup_done'} :
		&text("licence_no_lines", "<tt>$upgrade_virtualmin_host</tt>"));
	}

# Update Webmin updates file
&foreign_require("webmin");
if ($webmin::config{'upsource'} =~ /\Q$upgrade_virtualmin_host\E/) {
	&$first_print("Updating Webmin module updates URL ..");
	&lock_file($webmin::module_config_file);
	@upsource = split(/\t/, $webmin::config{'upsource'});
	foreach my $u (@upsource) {
		if ($u =~ /^(http|https|ftp):\/\/([^:]+):([^\@]+)\@($upgrade_virtualmin_host.*)$/) {
			$u = $1."://".$serial.":".$key."\@".$4;
			}
		}
	$webmin::config{'upsource'} = join("\t", @upsource);
	&webmin::save_module_config();
	&unlock_file($webmin::module_config_file);
	&$second_print($text{'setup_done'});
	}

# Update Virtualmin licence file
&$first_print($text{'licence_updfile'});
&lock_file($virtualmin_license_file);
%lfile = ( 'SerialNumber' => $serial,
           'LicenseKey' => $key );
&write_env_file($virtualmin_license_file, \%lfile);
&unlock_file($virtualmin_license_file);
if (defined($status) && $status == 0) {
	# Update the status file
	if (!$nocheck) {
		&read_file($licence_status, \%licence);
		# Update the licence status based on the new licence as
		# Virtualmin server can block on too many requests
		$licence{'status'} = $status;
		$licence{'expiry'} = $exp;
		$licence{'doms'} = $doms;
		$licence{'servers'} = $server;
		&update_licence_from_site(\%licence);
		&write_file($licence_status, \%licence);
		}
	}
&$second_print($text{'setup_done'});
}

1;

