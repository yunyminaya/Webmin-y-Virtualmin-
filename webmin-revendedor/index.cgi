#!/usr/bin/perl

# Módulo Webmin: Revendedores (GPL Emulado)
# UI mínima para invocar /usr/local/bin/virtualmin-revendedor

use strict;
use warnings;

our (%in);

require '../web-lib.pl';
&init_config();
&ReadParse();

my $title = 'Revendedores (GPL Emulado)';
&header($title, '', '');

my $action = $in{'action'} || '';

if ($action eq 'create') {
    my ($usuario, $pass, $dominio, $email, $desc,
        $max_doms, $max_realdoms, $max_mailboxes, $max_dbs, $max_aliases,
        $allow, $caps) = (
        $in{'usuario'}, $in{'pass'}, $in{'dominio'}, $in{'email'}, $in{'desc'},
        $in{'max_doms'}, $in{'max_realdoms'}, $in{'max_mailboxes'}, $in{'max_dbs'}, $in{'max_aliases'},
        $in{'allow'}, $in{'caps'}
    );

    # Validaciones básicas
    $usuario =~ /^[A-Za-z0-9._-]{1,32}$/ || &error("Usuario inválido");
    length($pass) >= 6 || &error("La contraseña debe tener al menos 6 caracteres");
    $dominio =~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/ || &error("Dominio base inválido");
    $email = '' if (defined $email && $email !~ /^[A-Za-z0-9._%+-]+\@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/);

    my @cmd = ('/usr/local/bin/virtualmin-revendedor', 'crear',
               '--usuario', $usuario,
               '--pass', $pass,
               '--dominio-base', $dominio);
    push @cmd, ('--email', $email) if $email;
    push @cmd, ('--desc', $desc) if defined $desc && $desc ne '';
    push @cmd, ('--max-doms', $max_doms) if $max_doms;
    push @cmd, ('--max-realdoms', $max_realdoms) if $max_realdoms;
    push @cmd, ('--max-mailboxes', $max_mailboxes) if $max_mailboxes;
    push @cmd, ('--max-dbs', $max_dbs) if $max_dbs;
    push @cmd, ('--max-aliases', $max_aliases) if $max_aliases;
    push @cmd, ('--allow', $allow) if $allow;
    push @cmd, ('--caps', $caps) if $caps;

    my $out = &backquote_command(join(' ', map { quotemeta($_) } @cmd).' 2>&1');
    my $rc = $? >> 8;

    print &ui_hr();
    print &ui_subheading('Resultado de la creación');
    print '<pre>'.&html_escape($out)."</pre>\n";
    if ($rc == 0) {
        print &ui_alert_success('Revendedor creado correctamente.');
    } else {
        print &ui_alert_box('Error creando el revendedor. Revisa la salida.', 'error');
    }
    print &ui_hr();
}
elsif ($action eq 'list') {
    my $dominio = $in{'dominio'} || '';
    $dominio =~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/ || &error('Dominio base inválido');
    my $out = &backquote_command('/usr/local/bin/virtualmin-revendedor listar --dominio-base '.quotemeta($dominio).' 2>&1');
    print &ui_hr();
    print &ui_subheading('Administradores en el dominio base');
    print '<pre>'.&html_escape($out)."</pre>\n";
    print &ui_hr();
}

# Formulario principal
print &ui_form_start('index.cgi');
print &ui_table_start('Crear revendedor', 'width=100%');
print &ui_table_row('Usuario', &ui_textbox('usuario', '', 20));
print &ui_table_row('Contraseña', &ui_password('pass', '', 20));
print &ui_table_row('Dominio base', &ui_textbox('dominio', '', 40));
print &ui_table_row('Email (opcional)', &ui_textbox('email', '', 40));
print &ui_table_row('Descripción', &ui_textbox('desc', 'Cuenta de revendedor', 50));
print &ui_table_row('Máx. sub-servidores', &ui_textbox('max_doms', '20', 8));
print &ui_table_row('Máx. reales', &ui_textbox('max_realdoms', '20', 8));
print &ui_table_row('Máx. buzones', &ui_textbox('max_mailboxes', '200', 8));
print &ui_table_row('Máx. DBs', &ui_textbox('max_dbs', '50', 8));
print &ui_table_row('Máx. alias', &ui_textbox('max_aliases', '200', 8));
print &ui_table_row('Features (permitir)', &ui_textbox('allow', 'web dns mail webmin mysql postgres ssl logrotate', 60));
print &ui_table_row('Capacidades', &ui_textbox('caps', 'domain users aliases dbs scripts mail backup sched restore ssl phpver phpmode admins records spf redirect forward sharedips catchall allowedhosts passwd disable delete', 90));
print &ui_table_end();
print &ui_hidden('action', 'create');
print &ui_form_end([ [ undef, 'Crear revendedor' ] ]);

print &ui_hr();

print &ui_form_start('index.cgi');
print &ui_table_start('Listar administradores (dominio base)', 'width=100%');
print &ui_table_row('Dominio base', &ui_textbox('dominio', '', 40));
print &ui_table_end();
print &ui_hidden('action', 'list');
print &ui_form_end([ [ undef, 'Listar' ] ]);

&footer('');

