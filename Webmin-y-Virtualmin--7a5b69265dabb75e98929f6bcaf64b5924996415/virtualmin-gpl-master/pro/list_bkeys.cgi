#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './virtual-server-lib.pl';
&ReadParse();

if (defined(&can_backup_keys)) {
	&can_backup_keys() ||
		&error($text{'backup_ekeycannot'} || 'You cannot manage backup encryption keys');
}

&ui_print_header(undef, $text{'index_bkeys'} || 'Backup Encryption Keys', '', 'bkeys');

my @keys;
if (defined(&list_backup_keys)) {
	@keys = &list_backup_keys();
	}
else {
	my $keyring = '/etc/webmin/virtual-server/bkeys';
	if (-d $keyring) {
		my $out = `gpg --homedir $keyring --list-keys --with-colons 2>/dev/null`;
		foreach my $line (split(/\n/, $out)) {
			my @f = split(/:/, $line);
			next if ($f[0] ne 'pub');
			push(@keys, {
				'id' => $f[4] || 'unknown',
				'desc' => 'GPG backup key',
				'owner' => 'root',
				'created' => $f[5] || undef,
				});
			}
		}
	}
print &ui_columns_start([
	$text{'backup_key'} || 'Key ID',
	$text{'desc'} || 'Description',
	$text{'owner'} || 'Owner',
	$text{'created'} || 'Created'
]);

foreach my $key (@keys) {
	print &ui_columns_row([
		&html_escape($key->{'id'}),
		&html_escape($key->{'desc'} || ''),
		&html_escape($key->{'owner'} || 'root'),
		$key->{'created'} ? &make_date($key->{'created'}) : '-'
	]);
}
print &ui_columns_end();

if (!@keys) {
	print &ui_message('No backup encryption keys are currently available');
}

print "<p><tt>virtualmin list-backup-keys --multiline</tt></p>\n";
&ui_print_footer('', $text{'index_return'} || 'Return');
