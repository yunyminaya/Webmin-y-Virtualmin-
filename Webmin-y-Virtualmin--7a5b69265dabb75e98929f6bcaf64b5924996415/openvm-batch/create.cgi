#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-batch-lib.pl';
&ReadParse();

ovmbatch_require_access();
my $cfg = ovmbatch_module_config();

&ui_print_header(undef, 'OpenVM Batch - Crear dominios', '', 'create');

if ($in{'action'} eq 'preview' || $in{'action'} eq 'execute') {
	my $csv_text = $in{'csv_data'} || '';
	my $dry_run  = ($in{'action'} eq 'preview') ? 1
		     : ($in{'dry_run'} eq '1')      ? 1
		     :                                 0;

	my ($rows, $errors) = ovmbatch_parse_csv($csv_text);

	if (@$errors) {
		print "<p><strong>Errores en el CSV:</strong></p><ul>\n";
		print "<li>".&html_escape($_)."</li>\n" for @$errors;
		print "</ul>\n";
		}

	if (@$rows) {
		my $results = $dry_run ? ovmbatch_dry_run($rows)
				      : ovmbatch_execute($rows, 0);

		print "<p>".($dry_run ? "Vista previa" : "Resultado de la creación")
		    ." — ".scalar(@$results)." dominios procesados:</p>\n";

		print &ui_columns_start(['Dominio', 'Usuario', 'Acción / Estado', 'Mensaje']);
		foreach my $r (@$results) {
			my $status_col = $r->{'ok'} ? 'green' : '#cc7700';
			my $action = $r->{'action'} || ($r->{'ok'} ? 'OK' : 'ERROR');
			print &ui_columns_row([
				&html_escape($r->{'domain'}),
				&html_escape($r->{'user'}),
				'<span style="color:'.$status_col.'">'.&html_escape($action).'</span>',
				&html_escape($r->{'msg'} || '-'),
			]);
			}
		print &ui_columns_end();

		if ($dry_run && @$rows) {
			my $hidden_csv = &html_escape($csv_text);
			print "<form method='post' action='create.cgi'>\n";
			print "<input type='hidden' name='action' value='execute'>\n";
			print "<input type='hidden' name='csv_data' value='$hidden_csv'>\n";
			print "<input type='hidden' name='dry_run' value='0'>\n";
			print &ui_submit('Confirmar y crear dominios');
			print "</form>\n";
			}
		}
	elsif (!@$errors) {
		print defined(&ui_message)
			? &ui_message('El CSV está vacío o no contiene filas válidas')
			: "<p>El CSV está vacío o no contiene filas válidas</p>\n";
		}
	}
else {
	# Show CSV input form
	print "<p>Pega el contenido CSV con los dominios a crear:</p>\n";
	print "<form method='post' action='create.cgi'>\n";
	print "<input type='hidden' name='action' value='preview'>\n";
	print &ui_table_start('Datos CSV', 'width=100%', 2);
	print &ui_table_row('CSV',
		"<textarea name='csv_data' rows='12' cols='80' style='font-family:monospace'>"
		. "domain,user,password,plan,email\n"
		. "ejemplo.com,ejemplo,SecurePass1,,admin\@ejemplo.com\n"
		. "</textarea>");
	print &ui_table_end();
	print &ui_submit('Vista previa (dry-run)');
	print "</form>\n";
	}

print &ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
