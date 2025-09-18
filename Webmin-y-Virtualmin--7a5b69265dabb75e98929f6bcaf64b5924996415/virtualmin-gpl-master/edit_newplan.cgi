#!/usr/local/bin/perl
# Show a list of all plans the current user owns

require './virtual-server-lib.pl';
$canplans = &can_edit_plans();
$canplans || &error($text{'plans_ecannot'});
&ui_print_header(undef, $text{'plans_title'}, "", "plans");

# Get plans and make the table
$bsize = &quota_bsize("home");
@plans = &list_editable_plans();
@table = ( );
$defplan = &get_default_plan(1);
foreach $plan (@plans) {
	local @cols;
	push(@cols, { 'type' => 'checkbox', 'name' => 'd',
		      'value' => $plan->{'id'} });
	push(@cols, ui_link("edit_plan.cgi?id=$plan->{'id'}'",
		    &html_escape($plan->{'name'} || $plan->{'id'})).
		    	($defplan && $defplan->{'id'} == $plan->{'id'} ? 
		    		&vui_inline_label('plans_default', 1) : ""));
	if ($canplans == 2) {
		push(@cols, $plan->{'owner'} ||
			    "<i>$text{'plans_noresel'}</i>");
		}
	push(@cols, $plan->{'quota'} ? &nice_size($plan->{'quota'}*$bsize)
				     : $text{'form_unlimit'});
	push(@cols, $plan->{'bwlimit'} ? &nice_size($plan->{'bwlimit'})
				       : $text{'form_unlimit'});
	push(@cols, $plan->{'domslimit'} eq '' ? $text{'form_unlimit'}
					       : $plan->{'domslimit'});
	push(@cols, $plan->{'mailboxlimit'} eq '' ? $text{'form_unlimit'}
					          : $plan->{'mailboxlimit'});
	push(@cols, $plan->{'aliaslimit'} eq '' ? $text{'form_unlimit'}
					        : $plan->{'aliaslimit'});
	push(@table, \@cols);
	}

# Show the table
@aplans = &list_available_plans();
print &ui_form_columns_table(
	"delete_plans.cgi",
	[ [ "delete", $text{'plans_delete'} ],
	  @aplans ? ( [ "default", $text{'plans_setdefault'} ] ) : ( ),
	],
	1,
	[ [ "edit_plan.cgi?new=1", $text{'plans_add'} ] ],
	undef,
	[ "", $text{'plans_name'},
	  $canplans == 2 ? ( $text{'plans_resel'} ) : ( ),
	  $text{'plans_quota'}, $text{'plans_bw'},
	  $text{'plans_doms'}, $text{'plans_mailboxes'},
	  $text{'plans_aliases'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$canplans == 2 ? $text{'plans_none'} : $text{'plans_none2'});

&ui_print_footer("", $text{'index_return'});
