#!/usr/local/bin/perl
# Show spam and virus delivery options for a virtual server

require './virtual-server-lib.pl';
&ReadParse();
$d = &get_domain($in{'dom'});
&can_edit_domain($d) || &error($text{'edit_ecannot'});
&can_edit_spam() || &error($text{'spam_ecannot'});

&ui_print_header(&domain_in($d), $text{'spam_title'}, "");

print &ui_form_start("save_spam.cgi");
print &ui_hidden("dom", $d->{'id'}),"\n";
print &ui_table_start($text{'spam_header'}, undef, 2);

# Work out what we can edit
if ($d->{'spam'}) {
	($smode, $sdest, $slevel) = &get_domain_spam_delivery($d);
	if ($smode >= 0) {
		push(@what, [ 'spam', $smode, $sdest ]);
		}
	}
if ($d->{'virus'}) {
	($vmode, $vdest) = &get_domain_virus_delivery($d);
	if ($vmode >= 0) {
		push(@what, [ 'virus', $vmode, $vdest ]);
		}
	}

# Show the inputs for spam and/or virus
foreach $w (@what) {
	# Show fields for dest
	($pfx, $vmode, $vdest) = @$w;
	$folder = $vmode == 4 || $vmode == 6 ? $vdest :
		  $pfx eq "spam" ? &default_spam_folder_suffix($d) : "Virus";
	print &ui_table_row(&hlink($text{'spam_'.$pfx}, 'spam_'.$pfx),
	 &ui_radio($pfx."_mode", $vmode,
	  [ [ 0, $text{'spam_'.$pfx.'0'}."<br>" ],
	    $pfx eq 'spam' ? ( [ 5, $text{'spam_'.$pfx.'5'}."<br>" ] ) : ( ),
	    [ 4, &text('spam_'.$pfx.'4', "<tt>~/mail/$folder</tt>")."<br>" ],
	    [ 6, &text('spam_'.$pfx.'6', "<tt>~/Maildir/.$folder/</tt>")."<br>" ],
	    [ 1, &text('spam_'.$pfx.'1',
	       &ui_textbox($pfx."_file", $vmode == 1 ? $vdest : "", 30))."<br>" ],
	    [ 2, &text('spam_'.$pfx.'2',
	       &ui_textbox($pfx."_email", $vmode == 2 ? $vdest : "", 30))."<br>" ],
	    [ 3, &text('spam_'.$pfx.'3',
	       &ui_textbox($pfx."_dest", $vmode == 3 ? $vdest : "", 30))."<br>" ]]));
	}

# Show spam delete level
if ($d->{'spam'}) {
	print &ui_table_row(&hlink($text{'spam_level'}, 'spam_level'),
	    &ui_opt_textbox("spamlevel", $slevel, 5, $text{'spam_nolevel'}));
	}

# Show input for option to whitelist all mailboxes
if ($d->{'spam'} && &get_domain_spam_client($d) ne "spamc") {
	print &ui_table_row(&hlink($text{'spam_white'}, 'spam_white'),
		    &ui_yesno_radio("spam_white", int($d->{'spam_white'})));
	}

# Show automatic spam clearing option
$auto = &get_domain_spam_autoclear($d);
print &ui_table_row(&hlink($text{'spam_clear'}, 'spam_clear'),
	&ui_radio("clear", $auto->{'days'} ne '' ? 1 :
			   $auto->{'size'} ne '' ? 2 : 0,
		[ [ 0, $text{'no'}."<br>" ],
		  [ 1, &text('spam_cleardays',
		    &ui_textbox("days", $auto->{'days'}, 5))."<br>" ],
		  [ 2, &text('spam_clearsize',
		    &ui_bytesbox("size", $auto->{'size'})) ],
		]));

# Show automatic trash clearing option
print &ui_table_row(&hlink($text{'spam_trashclear'}, 'spam_trashclear'),
	&ui_radio("trashclear", $auto->{'trashdays'} ne '' ? 1 :
				$auto->{'trashsize'} ne '' ? 2 : 0,
		[ [ 0, $text{'no'}."<br>" ],
		  [ 1, &text('spam_cleardays',
		    &ui_textbox("trashdays", $auto->{'trashdays'}, 5))."<br>" ],
		  [ 2, &text('spam_clearsize',
		    &ui_bytesbox("trashsize", $auto->{'trashsize'})) ],
		]));

# Show option to also clear spam and trash subfolders
print &ui_table_row(&hlink($text{'spam_subfolders'}, 'spam_subfolders'),
	&ui_yesno_radio("subfolders", $auto->{'subfolders'}));

# Show spamtrap option
$st = &get_spamtrap_aliases($d);
print &ui_table_row(&hlink($text{'spam_trap'}, 'spam_trap'),
	$st < 0 ? $text{'spam_trapcannot'} :
		  &ui_yesno_radio("trap", $st ? 1 : 0));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer(&domain_footer_link($d),
		 "", $text{'index_return'});

