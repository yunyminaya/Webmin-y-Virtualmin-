#!/usr/bin/perl

use strict;
use warnings;

our (%i18n_strings, $i18n_lang);

sub i18n_init
{
my ($lang) = @_;
$i18n_lang = $lang || $ENV{'HTTP_ACCEPT_LANGUAGE'} || 'en';
$i18n_lang =~ s/[^a-z]//g;
$i18n_lang = 'en' if (!$i18n_lang);
%i18n_strings = ();
# Cargar idioma base (inglés)
i18n_load_file('en');
# Cargar idioma seleccionado (sobreescribe)
i18n_load_file($i18n_lang) if ($i18n_lang ne 'en');
}

sub i18n_load_file
{
my ($lang) = @_;
# Buscar archivo en múltiples ubicaciones
my @paths = ("lang/$lang", "../lang/$lang", "../../lang/$lang");
for my $path (@paths) {
	if (-r $path) {
		open(my $fh, '<', $path) || next;
		while(my $line = <$fh>) {
			chomp($line);
			next if ($line =~ /^\s*#/ || $line !~ /=/);
			my ($key, $value) = split(/=/, $line, 2);
			$i18n_strings{$key} = $value if (defined($key) && $key ne '');
			}
		close($fh);
		return 1;
		}
	}
return 0;
}

sub t
{
my ($key) = @_;
return $i18n_strings{$key} || $key;
}

1;
