#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use autodie;

use UI::Dialog;
my $d = new UI::Dialog ( title => 'BashscriptCreator',
                         height => 25, width => 85 , listheight => 8,
                         order => [ 'whiptail' ] );
 
sub msgbox {
	my $text = shift;
	$d->msgbox(title => 'BashscriptCreator', text => $text);
}

sub yesno {
	my $text = shift;
	if ($d->yesno(text => $text) ) {
		return 1;
	} else {
		return 0;
	}
}

sub inputbox {
	my ($text, $default) = (shift, shift // '');
	my $string = $d->inputbox(text => $text, entry => $default);
	if ($d->state() ne "OK") {
		exit 0;
	}
	return $string;
}

sub menu {
	my $text = shift;
	my $selection = $d->menu(text => 'Select one:', list => \@_);
	return $selection;
}

sub checklist {
	my $text = shift;
	my @selection1 = $d->checklist( text => $text, list => \@_);
	return @selection1;
}

main();

sub main {
	my $filename = ''; 

	my $script = "#!/bin/bash\n";

	while (!$filename) {
		$filename = inputbox("Filename without .sh");
		$filename =~ s#\.sh{1,}$#.sh#g;
		if(-e "$filename.sh") {
			msgbox("The file `$filename already exists. Choose another one please.");
			$filename = ''; 
		}
	}
	$filename .= ".sh";

	my @options = checklist("Which options should be enabled?", 
		"set -e", ["auto-die on error", 1], 
		"set -o pipefail", ["fail if a command in a pipe fails", 1],
		"set -u", ["exit script if a variable is undefined", 0],
		"set -x", ["show lines before executing them", 0],
		"calltrace", ["Show call trace when the bash script dies", 1],
		"define lmod stuff", ["Defines ml and module for module load", 0]

	);
	foreach my $option (@options) {
		if($option =~ m#^set -([exu]|o pipefail)$#) {
			$script .= "$option\n";
		} elsif ($option eq "define lmod stuff") {
			$script .= "LMOD_DIR=/usr/share/lmod/lmod/libexec/\n";
			$script .= "LMOD_CMD=/usr/share/lmod/lmod/libexec/lmod\n";
			$script .= "module () {\n";
			$script .= "\teval `\$LMOD_CMD sh \"\$@\"`\n";
			$script .= "\n}\n";
			$script .= "ml () {\n";
			$script .= "\teval \$(\$LMOD_DIR/ml_cmd \"\$@\")\n";
			$script .= "}\n";

		} elsif ($option eq "calltrace") {
			$script .= "\n";
			$script .= "function calltracer () {\n";
			$script .= "\techo 'Last file/last line:'\n";
			$script .= "\tcaller\n";
			$script .= "}\n";
			$script .= "trap 'calltracer' ERR\n";
			$script .= "\n";
		} else {
			warn "Unknown option $option";	
		}
	}

	if(yesno("Do you want to define variables?")) {
		my @variables = ();
		while ((my $param = inputbox("Enter a variable name to be used as cli parameters or nothing for ending parameter input.\n".
					"Example:\nvarname\nvarname=defaultvalue\nvarname=(INT)defaultvalue\n".
					"varname=(FLOAT)\nvarname=(STRING)defaultvalue")) ne "") {
			if($param) {
				push @variables, $param;
			}
		}

		if(@variables) {
			my $create_help = yesno("Auto create help?");

			if($create_help) {
				$script .= "function help () {\n";
				$script .= qq#\techo "Possible options:"\n#;

				foreach my $var (@variables) {
					my $name = $var;
					$name =~ s#=.*##g;
					my $helptext = "--$name";
					if($var =~ m#(INT|FLOAT|STRING)#) {
						my $type = $1;
						$helptext .= "=$type";
					}

					if($var =~ m#=\((INT|FLOAT|STRING)\)(.*)#) {
						while(length($helptext) < 50) {
							$helptext .= ' ';
						}
						$helptext .= " default value: $2";
					}
					$script .= qq#\techo "\t$helptext"\n#;
				}

				my $helptext = "--help";
				while(length($helptext) < 50) {
					$helptext .= ' ';
				}
				$helptext .= " this help";
				$script .= qq#\techo "\t$helptext"\n#;


				$helptext = "--debug";
				while(length($helptext) < 50) {
					$helptext .= ' ';
				}
				$helptext .= " Enables debug mode (set -x)";
				$script .= qq#\techo "\t$helptext"\n#;
				$script .= qq#\texit \$1\n#;

				$script .= "}\n"
			}

			foreach my $var (@variables) {
				my $var_exportable = $var;
				$var_exportable =~ s#\((INT|FLOAT|STRING|!empty)\)##g;
				$script .= "export $var_exportable\n";
			}

			$script .= "for i in \$@; do\n";
			$script .= "\tcase \$i in\n";
			foreach my $var (@variables) {
				my $name = $var;
				$name =~ s#=.*##g;
				$script .= "\t\t--$name=*)\n";
				$script .= "\t\t\t$name=\"\${i#*=}\"\n";
				if ($var =~ m#\((INT|FLOAT|STRING)\)#) {
					my $type = $1;
					if($type ne "STRING") {
						if($type eq "INT") {
							$script .= "\t\t\tre='^[+-]?[0-9]+\$'\n"
						} elsif ($type eq "FLOAT") {
							$script .= "\t\t\tre='^[+-]?[0-9]+([.][0-9]+)?\$'\n";
						}
						$script .= "\t\t\tif ! [[ \$$name =~ \$re ]] ; then\n";
						$script .= "\t\t\t\techo \"error: Not a $type: \$i\" >&2\n";
						$script .= "\t\t\t\thelp 1\n";
						$script .= "\t\t\tfi\n";
					}
				}

				$script .= "\t\t\tshift\n";
				$script .= "\t\t\t;;\n";
			}


			if($create_help) {
				$script .= "\t\t-h|--help)\n";
				$script .= "\t\t\thelp 0\n";
				$script .= "\t\t\t;;\n";
			}

			$script .= "\t\t--debug)\n";
			$script .= "\t\t\tset -x\n";
			$script .= "\t\t\t;;\n";

			$script .= "\t\t*)\n";
			$script .= "\t\t\techo \"Unknown parameter \$i\" >&2\n";
			if($create_help) {
				$script .= "\t\t\thelp 1\n";
			}
			$script .= "\t\t\t;;\n";

			$script .= "\tesac\n";
			$script .= "done\n";
		}
	}

	open my $fh, '>', $filename;
	print $fh $script;
	close $fh;

	print "Written $filename\n";
}

