#!/usr/local/bin/perl
# Show one template for editing

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'newtmpl_ecannot'});
&ReadParse();

@tmpls = &list_templates();
if ($in{'new'}) {
	if ($in{'clone'}) {
		# Start with template we are cloning
		($tmpl) = grep { $_->{'id'} == $in{'clone'} } @tmpls;
		$tmpl || &error("Failed to find template with ID $in{'clone'} to clone");
		$tmpl->{'name'} .= " (Clone)";
		$tmpl->{'standard'} = 0;
		&ui_print_header(undef, $text{'tmpl_title3'}, "", "tmpls");
		}
	elsif ($in{'cp'}) {
		# Start with the default settings
		($tmpl) = grep { $_->{'id'} == 0 } @tmpls;
		$tmpl->{'name'} .= " (Copy)";
		$tmpl->{'standard'} = 0;
		$tmpl->{'default'} = 0;
		&ui_print_header(undef, $text{'tmpl_title4'}, "", "tmpls");
		}
	else {
		# Start with an empty template
		&ui_print_header(undef, $text{'tmpl_title1'}, "", "tmpls");
		}
	}
else {
	($tmpl) = grep { $_->{'id'} == $in{'id'} } @tmpls;
	$tmpl || &error("Failed to find template with ID $in{'id'}");
	&ui_print_header($tmpl->{'name'}, $text{'tmpl_title2'}, "", "tmpls");
	}

# Show section selector form
@editmodes = &list_template_editmodes($tmpl);
$in{'editmode'} ||= 'basic';
($editmode) = grep { $_->[0] eq $in{'editmode'} } @editmodes;
if (!$in{'new'}) {
	# Work out template section to edit
	$idx = &indexof($editmode, @editmodes);
	if ($in{'nprev'}) {
		$idx--;
		$idx = @editmodes-1 if ($idx < 0);
		}
	elsif ($in{'nnext'}) {
		$idx++;
		$idx = 0 if ($idx >= @editmodes);
		}
	$editmode = $editmodes[$idx];

	# Can only edit basic settings for new template!
	print &ui_form_start("edit_tmpl.cgi");
	print &ui_hidden("id", $in{'id'}),"\n";
	print &ui_hidden("new", $in{'new'}),"\n";
	print $text{'tmpl_editmode'},"\n";
	%isfeature = map { $_, 1 } @features;
	print &ui_select("editmode", $editmode->[0],
			 [ map { [ $_->[0], $_->[1] ] } @editmodes ],
			 1, 0, 0, 0, "onChange='form.submit()'" );
	print &ui_submit($text{'tmpl_switch'});
	print "&nbsp;&nbsp;\n";
	print &ui_submit($text{'tmpl_nprev'}, "nprev");
	print &ui_submit($text{'tmpl_nnext'}, "nnext");
	print &ui_form_end();
	}

print &ui_form_start("save_tmpl.cgi", "post");
print &ui_hidden("id", $in{'id'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("cloneof", $in{'clone'}),"\n";
print &ui_hidden("cp", $in{'cp'}),"\n";
print &ui_hidden("editmode", $editmode->[0]),"\n";
$emode = $text{'tmpl_editmode_'.$editmode->[0]} ||
	 $text{'feature_'.$editmode->[0]};
print &ui_table_start($emode, "width=100%", 2,
		      [ "width=30%" ]);

# Show selected options type
$sfunc = "show_template_".$editmode->[0];
if (defined(&$sfunc)) {
	&$sfunc($tmpl);
	}
else {
	$donehr = 1;
	}
foreach my $p (@{$editmode->[2]}) {
	print &ui_table_hr() if (!$donehr++);
	print &plugin_call($p, "template_input", $tmpl);
	}

print &ui_table_end();

# Buttons to save, create or delete
print &ui_form_end([
	[ "save", $in{'new'} ? $text{'create'} : $text{'save'} ],
	[ "next", $in{'new'} ? $text{'tmpl_cnext'} : $text{'tmpl_snext'} ],
	$in{'new'} || $tmpl->{'default'} ? ( ) :
		( [ "clone", $text{'tmpl_clone'} ] ),
	!$in{'new'} && !$tmpl->{'standard'} ?
		( [ "delete", $text{'delete'} ] ) : ( ),
	]);

# Hack to make any fields that are disabled by JS get disabled on form load
print "<script>",&virtualmin_ui_apply_radios(),"</script>\n";

&ui_print_footer("edit_newtmpl.cgi", $text{'newtmpl_return'},
		 "", $text{'index_return'});

# none_def_input(name, value, final-option, no-none, no-default, none-text,
#		 &disable-fields, [no-disable-on-none])
sub none_def_input
{
local ($name, $value, $final, $nonone, $nodef, $nonemsg, $dis, $nodisnone) = @_;
local $rv;
local $mode = $value eq "none" ? 0 :
	      $value eq "" ? 1 : 2;
local @opts;
push(@opts, 0) if (!$nonone);
push(@opts, 1) if (!$tmpl->{'default'} && !$nodef);
push(@opts, 2);
if (@opts > 1) {
	local $m;
	local $dis1 = @$dis ? &js_disable_inputs($dis, [ ]) : undef;
	local $dis2 = @$dis ? &js_disable_inputs([ ], $dis) : undef;
	foreach $m (@opts) {
		local $disn = $m == 2 ? $dis2 :
			      $m == 0 && $nodisnone ? $dis2 :
			      $m == 0 && !$nodisnone ? $dis1 :
				        $dis1;
		$rv .= &ui_oneradio($name."_mode", $m,
			$m == 0 ? ($nonemsg || $text{'newtmpl_none'}) :
			$m == 1 ? $text{'tmpl_default'} : $final,
			$mode == $m,
			$disn ? "onClick='$disn'" : "")."\n";
		}
	}
else {
	$rv .= &ui_hidden($name."_mode", $opts[0])."\n";
	}
return $rv;
}

