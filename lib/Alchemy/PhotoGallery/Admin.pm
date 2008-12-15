package Alchemy::PhotoGallery::Admin;

use strict;

#use Apache2::Request;
use Apache2::Request;
use File::Find::Rule;
use Image::Magick;
use Image::ExifTool;

use KrKit::Control;
use KrKit::Handler;
use KrKit::HTML qw( :all );
use KrKit::Validate;

use Alchemy::PhotoGallery;

use vars qw( @ISA );

############################################################
# Variables                                                #
############################################################
@ISA = ( 'Alchemy::PhotoGallery', 'KrKit::Handler' );

############################################################
# Functions                                                #
############################################################

##
## Note
## To Modify Images (files) and Directories - use Alchemy::FileManager
##

#-------------------------------------------------
# $site->do_copyright( $r )
#-------------------------------------------------
sub do_copyright {
	my ( $site, $r ) = @_;

#	my $in				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Annotate Image';

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, $site->{rootp} ) );
	}
	
	if ( ! ( my @errors = copyright_checkvals( $site, $in ) ) ) {
		
		## Prepare the attributes list
		my %attrib;

		## Required inputs
		$attrib{text}		= $in->{text};
		$attrib{font}		= "$site->{fontdir}/$in->{font}"; 
		$attrib{weight}		= $in->{weight};
		$attrib{pointsize}	= $in->{pointsize};
		$attrib{fill}		= $in->{fill};
		$attrib{gravity}	= $in->{gravity};
		$attrib{antialias}	= $in->{antialias};
		$attrib{style}		= $in->{style};

		## Everything else
		if ( is_text( $in->{family} ) ) {
			$attrib{family}			= $in->{family};
		}
		if ( is_text( $in->{style} ) ) {
			$attrib{style}			= $in->{style};
		}
		if ( is_text( $in->{stroke} ) ) {
			$attrib{stroke}			= $in->{stroke};
		}
		if ( is_integer( $in->{x} ) ) {
			$attrib{x}				= $in->{x};
		}
		if ( is_integer( $in->{y} ) ) {
			$attrib{y}				= $in->{y};
		}
		if ( is_float( $in->{rotate} ) ) {
			$attrib{rotate}			= $in->{rotate};
		}
		if ( is_float( $in->{skewX} ) ) {
			$attrib{skewX}			= $in->{skewX};
		}
		if ( is_float( $in->{skewY} ) ) {
			$attrib{skewY}			= $in->{skewY};
		}
		if ( is_text( $in->{align} ) ) {
			$attrib{align}			= $in->{align};
		}
		if ( is_text( $in->{stretch} ) ) {
			$attrib{stretch}		= $in->{stretch};
		}
		if ( is_integer( $in->{strokewidth} ) ) {
			$attrib{strokewidth}	= $in->{strokewidth};
		}
		if ( is_text( $in->{undercolor} ) ) {
			$attrib{undercolor}		= $in->{undercolor};
		}

		## If this is a file, we do it just to the file, if it is a directory
		## then we will do it to all files included in that directory and its
		## subdirectories
		if ( is_text( $in->{image} ) ) {
		
			## Must be a single file
			my $image	= Image::Magick->new;

			my $error	= $image->Read( "$site->{gallerydir}/$in->{image}" );

			if ( ! $error ) {

				$image->Annotate( %attrib );
	
				$image->Write( "$site->{gallerydir}/$in->{image}" );

				undef( $image );
			}
			else {
				return( 'Encountered an error:', $error );
			}
		}
		else {
		
			## Must be a directory
			my $path	= "$site->{gallerydir}/$in->{dir}";
			$path		=~ s/\/\//\//g;
			
			my @dirs	= ();

			## If we are instructed to do this recursively, then do so
			if ( $in->{descend} ) {
				@dirs = File::Find::Rule	-> directory
											-> relative
											-> in( $path );
			}
			else {
				## or don't....
				@dirs = File::Find::Rule	-> directory
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> in( $path );
			}
			
			## Loop through each directory
			foreach my $ldir ( @dirs ) {
				my $lpath = "$path/$ldir";
				$lpath =~ s/\/\//\//g;

				my @files = File::Find::Rule	-> file
												-> relative
												-> name( @{$site->{extary}} )
												-> maxdepth( 1 )
												-> mindepth( 1 )
												-> in( $lpath );

				## Go through and update the image
				foreach my $lfile ( @files ) {
				
					my $image = Image::Magick->new;

					my $error = $image->Read( "$lpath/$lfile" );

					if ( ! $error ) {
						
						$image->Annotate( %attrib );

						$image->Write( "$lpath/$lfile" );

						undef( $image );
					}
					else {
						return( 'Encountered an error:', $error );
					}
				}
			}
		}
		
		return( $site->_relocate( $r, $site->{rootp} ) );
	}
	else {
		## Defaults
		$in->{font}			= '/usr/share/fonts/default/Type1/c059036l.pfb'
			if ( ! defined $in->{font} );
		$in->{pointsize}	= '15'			if ( ! defined $in->{pointsize} );
		$in->{fill}			= 'white'		if ( ! defined $in->{fill} );
		$in->{gravity}		= 'SouthEast'	if ( ! defined $in->{gravity} );
		$in->{weight}		= '1000'		if ( ! defined $in->{weight} );
		$in->{antialias}	= '1'			if ( ! defined $in->{antialias} );
		$in->{style}		= 'Italic'		if ( ! defined $in->{style} );
		
		if ( $r->method eq 'POST' ) {
			return( ht_div( { 'class' => 'error' } ),
					@errors,
					ht_udiv(),
					copyright_form( $site, $in ) );
		}
		else {
			return( copyright_form( $site, $in ) );
		}
	}
} # END $site->do_copyright

#-------------------------------------------------
# $site->do_process( $r, @p )
#-------------------------------------------------
# Prepare directories for viewing
#-------------------------------------------------
sub do_process {
	my ( $site, $r, @p ) = @_;

	$site->{page_title}	.= ' Processing';
	
	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};

	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	## This is actually done by a common module - having to use the
	## admin module, means that we want to limit the capability of the users
	## - we want to make them prepare each directory
	my @errors			= $site->process_photos( $dir );

	## Need to return this to do_main
	return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );

} # END $site->do_prepare

#-------------------------------------------------
# $site->do_show( $r, $file )
#-------------------------------------------------
sub do_show {
	my ( $site, $r, @loc ) = @_;

	my $file				= pop( @loc );
	my $path				= join( '/', @loc );
	$path					=~ s/\/\//\//g;
	
	$site->{page_title}	.= " Show \"$file\"";

	if ( ! -e "$site->{gallerydir}/$path/$file" ) {
		return( ht_div( { 'class' => 'error' } ),
				"File Not Found: $!\n",
				ht_udiv() );
	}

	return( ht_div( { 'class' => 'box' } ),
			ht_table(),
			
			ht_tr(),
			ht_td( { 'class' => 'hdr' },
				ht_a( 'javascript://', 'Close Window', 
					'onClick="window.close()"' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'cdta' },
				ht_img( "$site->{gallroot}/$path/$file", 
					"title=\"$file\"", 
					"alt=\"$file\"" ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'chdr' }, $file ),
			ht_utr(),

			ht_utable(),
			ht_udiv() );
} # END $site->do_show

###################################
# Cleanup                         #
###################################

#-------------------------------------------------
# $site->do_clean( $r, @p )
#-------------------------------------------------
# Remove thumbnails from a directory
#-------------------------------------------------
sub do_clean {
	my ( $site, $r, @p ) = @_;

	$site->{page_title}	.= ' Remove Thumbs';
	
	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};

	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	## In case something fails....
	my @lines;
	
	## Loop through the list, removing each as we go
	if ( -e $dir ) {
			
		## The directory must be empty in order to remove it
		my @files = File::Find::Rule	-> file
										-> maxdepth( 1 )
										-> mindepth( 1 )
										-> in(	"$dir/$site->{gallthdir}",
												"$dir/$site->{smthdir}",
												"$dir/$site->{midsizedir}" );

		## Delete the files
		unlink( @files ) ||
			push( @lines, "Unable to remove files: $!\n" );

		## Now remove the directories
		rmdir( "$dir/$site->{gallthdir}" ) ||
			push( @lines, "Unable to remove $base/$site->{gallthdir}\n" );
		rmdir( "$dir/$site->{smthdir}" ) ||
			push( @lines, "Unable to remove $base/$site->{smthdir}\n" );
		rmdir( "$dir/$site->{midsizedir}" ) ||
			push( @lines, "Unable to remove $base/$site->{midsizedir}\n" );
	}

	## That 'should' be all there is to it.... now, were there any errors?
	if ( @lines ) {
		return( ht_div( { 'class' => 'error' } ),
				@lines,
				ht_udiv() );
	}
	
	return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
} # END $site->do_clean

###################################
# Captions                        #
###################################

#-------------------------------------------------
# $site->do_add( $r, @p )
#-------------------------------------------------
# Captions
#-------------------------------------------------
sub do_add {
	my ( $site, $r, @p ) = @_;

	$site->{page_title}	.= ' Add Caption File';

#	my $in 				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};
	
	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}

	if ( defined $in->{submit} && 
		! ( my @errors = caption_checkvals( $site, $in ) ) ) {
		
		if ( ! open( FILE, ">$dir/$site->{captionfile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Create caption file: $!\n",
					ht_udiv() );
		}

		## Since we need to sort the pictures based on the specified order
		## we will need to store them and write them out at the end
		my %pictures;
		my %captions;
		
		## Now just need to actually create the file....
		foreach my $key ( keys %{$in} ) {
			if ( $key eq 'title' && $in->{$key} ) {
				print FILE "TITLE - $in->{$key}\n";
			}
			elsif ( $key eq 'numrow' && $in->{$key} ) {
				print FILE "NUMROW - $in->{$key}\n";
			}
			elsif ( $key eq 'numpage' && $in->{$key} ) {
				print FILE "NUMPAGE - $in->{$key}\n";
			}
			elsif ( $key eq 'row' && $in->{$key} ) {
				my @lines = split( "\n", $in->{$key} );
				chomp( @lines );

				foreach my $entry ( @lines ) {
					$entry =~ /([0-9]*): (.*)$/;
					print FILE "ROW$1 $2\n";
				}
			}
			elsif ( $key eq 'showpic' ) {
				if ( $in->{$key} eq 'no' ) {
					print FILE "SHOWPICS - NO\n";
				}
			}
			elsif ( $key =~ /^pic(.*)/ ) {

				## If it still contains Select Image ('') then skip the entry
				next if ( $in->{$key} eq '' );
				
				## The sorting order is in the key itself
				my $order = $1;

				$pictures{$order}	= $in->{$key};
				$captions{$order}	= $in->{"cap$order"};
			}
			elsif ( $key eq 'galthumb' ) {
				
				## If it still cotains Select Image ('') then skip the entry
				next if ( $in->{$key} eq '' );

				my $string = "GALTHUMB " . $in->{galthumb} . " - ";

				if ( $in->{galcap} ) {
					$string .= $in->{galcap};
				}
				
				print FILE "$string\n";
			}
		}

		## Now store the picutres
		foreach my $key ( sort { $a <=> $b } keys %pictures ) {
			my $string = "PIC $pictures{$key} - ";

			if ( $captions{$key} ) {
				$string .= $captions{$key};
				chomp( $string );
			}

			print FILE "$string\n";
		}
		
		close( FILE ) ||
			warn( "Unable to Close $dir/$site->{captionfile}: $!\n" );

		## Set the permissions
		system( $site->{chmod}, $site->{fperm}, "$dir/$site->{captionfile}" );
		system( $site->{chgrp}, $site->{group}, "$dir/$site->{captionfile}" );

		return( $site->_relocate( $r, "$site->{'rootp'}/main/$base" ) );
	}
	else {
		if ( $r->method eq 'POST' && defined $in->{submit} ) {
			return( ht_div( { 'class' => 'error' } ),
					@errors,
					ht_udiv(),
					caption_form( $site, $dir, $in ) );
		}
		else {
			## Create defaults
			$in->{numrow}	= $site->{galnumrow} 
								if ( ! defined $in->{numrow} );
			$in->{numpage}	= $site->{galnumpage} 
								if ( ! defined $in->{numpage} );
	
			## Default the images with captions
			my @subfiles	= File::Find::Rule	-> file
												-> relative
												-> maxdepth( 1 )
												-> mindepth( 1 )
												-> name( @{$site->{extary}} )
												-> in( $dir );

			my @files = sort { lc( $a ) cmp lc( $b ) } @subfiles;

			## Loop through and set them up
			for ( my $i = 1; $i < scalar( @files ) + 1; $i++ ) {
				$in->{"pic$i"} = $files[$i-1] if ( ! defined $in->{"pic$i"} );
				$in->{"cap$i"} = $files[$i-1] if ( ! defined $in->{"cap$i"} );
				$in->{numimg} = $i;
			}

			return( caption_form( $site, $dir, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_edit( $r, @p )
#-------------------------------------------------
# Captions
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, @p ) = @_;

#	my $in 				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Edit Caption File';

	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};

	$dir				= "$site->{gallerydir}/$base";
	$dir				=~ s/\/\//\//g;

	if ( $in->{'cancel'} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}

	## Make sure that we can work with the caption file
	if ( ! -e "$dir/$site->{captionfile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Invalid Caption file: $!\n",
				ht_udiv() );
	}

	if ( ! -w "$dir/$site->{captionfile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Unable to Write to Caption file: $!\n",
				ht_udiv() );
	}
	
	## Need to indicate that this is an edit
	$in->{edit} = 1;

	if ( defined $in->{submit} && 
		! ( my @errors = caption_checkvals( $site, $in ) ) ) {
		
			if ( ! open( FILE, ">$dir/$site->{captionfile}" ) ) {
				return( ht_div( { 'class' => 'error' } ),
						"Unable to Edit caption file: $!\n",
						ht_udiv() );
			}

			## Since we need to sort the pictures based on the specified order
			## we will need to store them and write them out at the end
			my %pictures;
			my %captions;

			## Now just need to actually update the file....
			foreach my $key ( keys %{$in} ) {
				if ( $key eq 'title' ) {
					print FILE "TITLE - $in->{$key}\n";
				}
				elsif ( $key eq 'numrow' ) {
					print FILE "NUMROW - $in->{$key}\n";
				}
				elsif ( $key eq 'numpage' ) {
					print FILE "NUMPAGE - $in->{$key}\n";
				}
				elsif ( $key eq 'row' ) {
					my @lines = split( "\n", $in->{$key} );
					chomp( @lines );
					foreach my $entry ( @lines ) {
						$entry =~ /^([0-9]*): (.*)$/;
						print FILE "ROW$1 $2\n";
					}
				}
				elsif ( $key eq 'showpic' ) {
					if ( $in->{$key} eq 'no' ) {
						print FILE "SHOWPICS - NO\n";
					}
				}
				elsif ( $key =~ /^pic(.*)/ ) {

					next if ( $in->{$key} eq '' );

					my $order = $1;

					$pictures{$order}	= $in->{$key};
					$captions{$order}	= $in->{"cap$order"};
				}
				elsif ( $key eq 'galthumb' ) {
					
					## If it is still Select Image (''), then skip the entry
					next if ( $in->{$key} eq '' );

					my $string = "GALTHUMB " . $in->{galthumb} . " - ";

					if ( $in->{galcap} ) {
						$string .= $in->{galcap};
					}

					print FILE "$string\n";
				}
			}
			
			## Now store the pictures
			foreach my $key ( sort { $a <=> $b } keys %pictures ) {
				my $string = "PIC $pictures{$key} - ";

				if ( $captions{$key} ) {
					$string .= $captions{$key};
					chomp( $string );
				}

				print FILE "$string\n";
			}
			
			close( FILE ) ||
				warn( "Unable to Close $dir/$site->{captionfile}: $!\n" );

			## Shouldn't have to - but reset the perms just in case
			system( $site->{chmod}, $site->{fperm}, 
					"$dir/$site->{captionfile}" );
			system( $site->{chgrp}, $site->{group}, 
				"$dir/$site->{captionfile}" );
					
			return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}
	else {
		if ( -e "$dir/$site->{captionfile}" ) {
		
			## Need to parse the existing caption file and set the variables...
			## being sure not to overwrite anything we have already modified...
			my $picorder = 0;

			## Due to the fact that there may be several lines for the row
			## element, we will have to take special care to build it
			my $rowline = '';

			## Let's read the caption file
			my $results = $site->read_caption( $dir, $base );

			## Check for errors
			return( ht_div( { 'class' => 'error' } ),
					'There was an error processing the caption file',
					ht_udiv() ) if ( $results->{error} );

			## TITLE
			$in->{title}	= $results->{title} if ( ! defined $in->{title} );

			## NUMROW
			$in->{numrow}	= $results->{numrow} if ( ! defined $in->{numrow} );

			## NUMPAGE
			$in->{numpage}	= $results->{numpage} 
								if ( ! defined $in->{numpage} );

			## ROWCAPS
			my @rowcaps		= @{$results->{rowcaps}};
			if ( ! defined $in->{row} ) {
				for ( my $i = 0; $i < scalar( @rowcaps ); $i++ ) {
					if ( $rowcaps[$i] ) {
						$rowline .= "$i: $rowcaps[$i]\n";
					}
				}
			}

			## SHOWPIC
			if ( ! defined $in->{showpic} ) {
				$in->{showpic}	= 'yes';
				$in->{showpic}	= 'no' if ( ! $results->{showpics} );
			}

			## GALTHUMB
			if ( ! defined $in->{galthumb} ) {
				$in->{galthumb}	= $results->{galthumb} || '';
				$in->{galcap}	= $results->{galcap} || '';
			}

			## PICS
			my @pics		= @{$results->{pictures}};
			my @caps		= @{$results->{captions}};
			my $numimg		= 0;
			
			for ( my $i = 1; $i < (scalar( @pics ) + 1); $i++ ) {
				$in->{"pic$i"} = $pics[$i-1] if ( ! defined $in->{"pic$i"} );
				$in->{"cap$i"} = $caps[$i-1] if ( ! defined $in->{"cap$i"} );

				$numimg++;
			}
		
			$in->{numimg} = $numimg if ( ! defined $in->{numimg} );

			## set the row element
			$in->{row}	= $rowline	if ( ! defined $in->{row} );
		}

		if ( $r->method eq 'POST' && defined $in->{submit} ) {
			return( ht_div( { 'class' => 'error' } ),
					@errors,
					ht_udiv(),
					caption_form( $site, $dir, $in ) );
		}
		else {
			return( caption_form( $site, $dir, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_delete( $r, @p )
#-------------------------------------------------
# Captions
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, @p ) = @_;

#	my $in 				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Delete Caption File';

	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};
	
	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}

	## Be sure that the file exists
	if ( ! -e "$dir/$site->{captionfile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Invalid Caption file: $!",
				ht_udiv() );
	}

	if ( defined $in->{yes} && $in->{yes} =~ /yes/ ) {
		
		if ( ! unlink( "$dir/$site->{captionfile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Delete caption file: $!",
					ht_udiv() );
		}

		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}
	else {
		return( ht_form_js( $site->{uri} ),
				ht_input( 'yes', 'hidden', { 'yes', 'yes' } ),
				ht_div( { 'class' => 'box' } ),
				ht_table(),

				ht_tr(),
				ht_td( { 'class' => 'dta' },
					'Delete the file:', ht_b( "$base/$site->{captionfile}" ),
					'? This will permanently remove this file from the',
					'system.' ),
				ht_utr(),

				ht_tr(),
				ht_td( { 'class' => 'rshd' },
					ht_submit( 'submit', 'Delete' ),
					ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),

				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}		
} # END $site->do_delete

#-------------------------------------------------
# $site->do_advcap( $r, @p )
#-------------------------------------------------
# Captions - Add and Edit
#-------------------------------------------------
sub do_advcap {
	my ( $site, $r, @p ) = @_;

#	my $in				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Advanced Caption File';

	my $base			= join( '/', @p );
	my $dir				= $site->{gallerydir};

	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}

	## If one exists - then we will need to be able to use it...
	if ( -e "$dir/$site->{captionfile}" ) {
		if ( ! -w "$dir/$site->{captionfile}" ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Write to Caption file: $!\n",
					ht_udiv() );
		}
	}

	## Since we don't care what they put in the file (advanced) - we will
	## do no error checking....
	if ( defined $in->{submit} ) {
		
		if ( ! open( FILE, ">$dir/$site->{captionfile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Edit caption file: $!\n",
					ht_udiv() );
		}

		print FILE $in->{text};

		close( FILE ) ||
			warn( "Unable to Close caption file: $!\n" );

		## Set the permissions
		system( $site->{chmod}, $site->{fperm},
				"$dir/$site->{captionfile}" );
		system( $site->{chgrp}, $site->{group},
				"$dir/$site->{captionfile}" );

		return( $site->_relocate( $r, "$site->{rootp}/main/$base" ) );
	}
	else {
		my @file = ();

		## If the file exists, use it - otherwise, don't
		if ( open( FILE, "<$dir/$site->{captionfile}" ) ) {
			@file = <FILE>;

			close( FILE ) ||
				warn( "Unable to Close caption file: $!\n" );
		}
		
		$in->{text} = join( '', @file );
		
		return(
			ht_form_js( $site->{uri} ),
			ht_div( { 'class' => 'box' } ),
			ht_table(),

			ht_tr(),
			ht_td( { 'class' => 'hdr', 'colspan' => '2' },
				'Caption File Contents' ),
			ht_utr(),
			
			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Contents' ),
			ht_td( { 'class' => 'dta' },
				ht_input( 'text', 'textarea', $in->{text}, 
					'rows="20" cols="60"' ),
				ht_help( $site->{help}, 'item', 'a:pg:a:captiontext' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
				ht_submit( 'submit', 'Save' ),
				ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
	}
} # END $site->do_advcap

###################################
# EXIF                            #
###################################

#-------------------------------------------------
# $site->do_addexif( $r )
#-------------------------------------------------
# EXIF file
#-------------------------------------------------
sub do_addexif {
	my ( $site, $r ) = @_;

#	my $in				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Add EXIF Attributes';
	
	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}

	## There are no errors to be had - it either goes, or it doesn't....
	if ( $r->method eq 'POST' ) {

		## Write the file out
		if ( ! open( FILE, ">$site->{gallerydir}/$site->{exiffile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Create EXIF file: $!\n",
					ht_udiv() );
		}

		print FILE $in->{text};

		close( FILE ) ||
			warn( "Unable to Close EXIF file: $!\n" );

		## Set the permissions
		system( $site->{chmod}, $site->{fperm},
			"$site->{gallerydir}/$site->{exiffile}" );
		system( $site->{chgrp}, $site->{group},
			"$site->{gallerydir}/$site->{exiffile}" );

		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}
	else {
		## Default
		$in->{text} = '--ALL--';

		return( exif_form( $site, $in ) );
	}
} # END $site->do_addexif

#-------------------------------------------------
# $site->do_editexif( $r, @p )
#-------------------------------------------------
# EXIF file
#-------------------------------------------------
sub do_editexif {
	my ( $site, $r, @p ) = @_;

#	my $in				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Edit EXIF Attributes';

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}

	## Make sure that we can work with the exif file
	if ( ! -e "$site->{gallerydir}/$site->{exiffile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Invalid EXIF file: $!\n",
				ht_udiv() );
	}
warn "*$site->{gallerydir}/$site->{exiffile}*\n";
	if ( ! -w "$site->{gallerydir}/$site->{exiffile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Unable to Write to EXIF file: $!\n",
				ht_udiv() );
	}

	## Open the file and grab the contents
	if ( ! open( FILE, "<$site->{gallerydir}/$site->{exiffile}" ) ) {
		return( ht_div( { 'class' => 'error' } ),
				"Unable to Open EXIF file: $!\n",
				ht_udiv() );
	}

	my @contents = <FILE>;
	$in->{text} = join( '', @contents ) if( ! defined $in->{text} );
	
	close( FILE ) ||
		warn( "Unable to Close EXIF file: $!\n" );
		
	## There are no errors to be had - it either goes, or it doesn't...
	if ( $r->method eq 'POST' ) {
		## Write the file out
		if ( ! open( FILE, ">$site->{gallerydir}/$site->{exiffile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Update EXIF file: $!\n",
					ht_udiv() );
		}
		
		print FILE $in->{text};
		
		close( FILE ) ||
			warn( "Unable to Close EXIF file: $!\n" );

		## Set the permissions
		system( $site->{chmod}, $site->{fperm},
			"$site->{gallerydir}/$site->{exiffile}" );
		system( $site->{chgrp}, $site->{group},
			"$site->{gallerydir}/$site->{exiffile}" );

		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}
	else {
		return( exif_form( $site, $in ) );
	}
} # END $site->do_editexif

#-------------------------------------------------
# $site->do_delexif( $r, @p )
#-------------------------------------------------
# Exif Info Files
#-------------------------------------------------
sub do_delexif {
	my ( $site, $r, @p ) = @_;

#	my $in				= $site->param( Apache2::Request->new( $r ) );
	my $apr				= Apache2::Request->new( $r );
	my $in				= $site->param( $apr );

	$site->{page_title}	.= ' Delete EXIF File';

	if ( $in->{cancel} ) {
		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}

	## Be sure that the file exists
	if ( ! -e "$site->{gallerydir}/$site->{exiffile}" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Invalid EXIF file: $!\n",
				ht_udiv() );
	}

	if ( defined $in->{yes} && $in->{yes} =~ /yes/ ) {
		
		if ( ! unlink( "$site->{gallerydir}/$site->{exiffile}" ) ) {
			return( ht_div( { 'class' => 'error' } ),
					"Unable to Delete EXIF file: $!\n",
					ht_udiv() );
		}

		return( $site->_relocate( $r, "$site->{rootp}/main" ) );
	}
	else {
		return( ht_form_js( $site->{uri} ),
				ht_input( 'yes', 'hidden', { 'yes', 'yes' } ),
				ht_div( { 'class' => 'box' } ),
				ht_table(),

				ht_tr(),
				ht_td( { 'class' => 'dta' },
					'Delete the file:', ht_b( $site->{exiffile} ),
					'? This will permanently remove this file from the',
					'system.' ),
				ht_utr(),

				ht_tr(),
				ht_td( { 'class' => 'rshd' },
					ht_submit( 'submit', 'Delete' ),
					ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),

				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}
} # END $site->do_delexif

#-------------------------------------------------
# $site->do_testexif( $r )
#-------------------------------------------------
sub do_testexif {
	my ( $site, $r ) = @_;
	
#	my $in			= $site->param( Apache2::Request->new( $r ) );
	my $apr			= Apache2::Request->new( $r );
	my $in			= $site->param( $apr );

	$in->{img}		= 'default' if ( ! defined $in->{img} );

	## Update the frame if specified
	$site->{frame}	= $site->{exifframe} if ( $site->{exifframe} );
	
	## No need for a 'cancel' - they can just close the window....
	
	## We need a default image from the config - the config should contain
	## the absolute path to the file on the filesystem
	my $default		= $site->{exiftestimg};
	$default		= $in->{img} if ( $in->{img} ne 'default' );
	$default		=~ s/\/\//\//g;

	## Get the list of possible image files from the gallery - exclude the
	## thumbnail directories (as usual)
	my @files		= ( 'default', '--Select--' );

	my @tpaths		= File::Find::Rule	-> file
										-> name( @{$site->{extary}} )
										-> in( "$site->{gallerydir}" );
	
	my @paths		= sort { lc( $a ) cmp lc( $b ) } @tpaths;
	chomp( @paths );
	foreach my $file ( @paths ) {
		my $lfile = $file;
		$lfile =~ s/$site->{gallerydir}//;

		## Again - skipping the thumbs...
		next if ( $lfile =~ /$site->{gallthdir}/ || 
			$lfile =~ /$site->{smthdir}/ || $lfile =~ /$site->{midsizedir}/ );

		push( @files, $file, $lfile );
	}

	my @lines = (
		ht_form_js( $site->{uri} ),

		'<script type="text/javascript">',
		'<!--',
		'function SendExif(Tag) {',
		'  window.opener.SetExif(Tag);', 
		'}', 
		'//-->',
		'</script>',

		ht_div( { 'class' => 'exif' } ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '3' },
			ht_h( '1', 'EXIF Data Test' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Image to Test',
			ht_help( $site->{help}, 'item', 'a:pg:a:testimage' ) ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'img', 1, $in->{img}, 0, '', @files ) ),
		ht_td( { 'class' => 'dta' }, ht_submit( 'submit', 'Test' ) ),
		ht_utr(),

		ht_utable(),
		ht_br(),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Tag Name',
			ht_help( $site->{help}, 'item', 'a:pg:a:tagname' ) ),
		ht_td( { 'class' => 'shd' }, 'Attribute Name',
			ht_help( $site->{help}, 'item', 'a:pg:a:attribname' ) ),
		ht_td( { 'class' => 'shd' }, 'Value',
			ht_help( $site->{help}, 'item', 'a:pg:a:examplevalue' ) ),
		ht_utr() );

	## Get the Exif Data
	my $exifTool	= new Image::ExifTool;
	$exifTool->Options( 'Unknown' => '1', 
						'Duplicates' => '0' );
	
	my $info		= $exifTool->ImageInfo( $default );

	foreach my $tag ( $exifTool->GetFoundTags() ) {
		my $name	= $exifTool->GetDescription( $tag );
		my $value	= $info->{$tag};

		chomp( $tag, $name, $value );

		next if ( $name =~ /Directory/i );
		next if ( ref( $value ) eq "SCALAR" );

		push( @lines,
			ht_tr(),
			ht_td( { 'class' => 'dta' }, 
				ht_a( "javascript:SendExif('$tag')", $tag ) ),
			ht_td( { 'class' => 'dta' }, $name ),
			ht_td( { 'class' => 'dta' }, $value ),
			ht_utr() ) if ( is_text( $value ) );
	}

	return( @lines,
			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END $site->do_testexif

#-------------------------------------------------
# $site->do_tree( $r, @p )
#-------------------------------------------------
# Let's us see what is ready, and what is not...
#-------------------------------------------------
sub do_tree {
	my ( $site, $r, @p ) = @_;

	$site->{page_title}	.= ' Gallery Tree';

	## Get the list of directories - assume no one is 'silly' enough to
	## create a directory depth of 10
	my @subdirs = File::Find::Rule	-> directory
									-> maxdepth( 10 )
									-> mindepth( 1 )
									-> in( "$site->{gallerydir}" );

	## For full coverage, include the top-level gallery
	push( @subdirs, $site->{gallerydir} );
	my @dirs = sort { lc( $a ) cmp lc( $b ) } @subdirs;

	## Begin the page
	my @lines = (
		ht_div( { 'class' => 'box' } ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'chdr', 'colspan' => '3' }, 'Gallery Tree' ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '3' },
			ht_a( "$site->{rootp}/main", 'Normal View' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Directories' ),
		ht_td( { 'class' => 'shd' }, 'Files' ),
		ht_td( { 'class' => 'shd' }, 'Actions' ),
		ht_utr() );

	## Let's see what we have here...
	foreach my $dir ( @dirs ) {
		my $ldir	= $dir;
		$ldir		=~ s/$site->{gallerydir}//;
		$ldir		=~ s/^\///;

		## Skip this directory if it is a thumbnail directory
		next if ( $ldir =~ /$site->{gallthdir}/ || 
				$ldir =~ /$site->{smthdir}/ ||
				$ldir =~ /$site->{midsizedir}/ );

		## We need to know what we have so that we can build the actions
		my @actions		= ();
		my $havecap		= 0;
		my $haveexif	= 0;
		my $haveimages	= 0;
		my $haveth		= 0;
		my $havesm		= 0;
		my $havemid		= 0;
		
		## See if the dir has any thumb directories or not
		my @tdirs		= File::Find::Rule	-> directory
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> in( "$dir" );
		
		foreach my $d ( @tdirs ) {
			$haveth++	if ( $d eq $site->{gallthdir} );
			$havesm++	if ( $d eq $site->{smthdir} );
			$havemid++	if ( $d eq $site->{midsizedir} );
		}

		## See if the dir has a caption file, a title file, or an EXIF file
		my @subfiles	= File::Find::Rule	-> file
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> in( "$dir" );

		my @files = sort { lc( $a ) cmp lc( $b ) } @subfiles;
		
		my @filelines	= ();
		
		foreach my $file ( @files ) {
			$file	=~ s/$dir//;
			$file	=~ s/^\///;

			if ( $file eq $site->{captionfile} || 
				$file eq $site->{exiffile} ) {
				push( @filelines, $file, ht_br() );
			}

			## See if there are files to edit or delete for the action links
			$havecap++		if ( $file eq $site->{captionfile} );
			$haveexif++		if ( $file eq $site->{exiffile} );
			$haveimages++	if ( $site->is_image( $file ) );
		}
		
		push( @filelines, $haveimages, 'Images', ht_br() ) if ( $haveimages );
		
		## We always want a link to the filemanager, so....
		push( @actions,
			'[', ht_a( "$site->{fmurl}/main$site->{gallroot}/$ldir", 
				'FileManager' ), 
			']', ht_br() );
			
		## What are our actions?
		if ( $ldir eq '' ) {
			## We don't care about the title or exif files for anything but the
			## top-level directory
			if ( $haveexif ) {
				push( @actions,
					'[', ht_a( "$site->{rootp}/editexif", 'Edit EXIF' ),
					'|', ht_a( "$site->{rootp}/delexif", 'Delete EXIF' ),
					']', ht_br() );
			}
			else {
				push( @actions,
					'[', ht_a( "$site->{rootp}/addexif", 'Add Exif' ),
					']', ht_br() );
			}
		}
		
		## If we have images, we need to be able to have thumbs too
		if ( ! $haveimages ) {
			if ( $haveth || $havesm || $havemid ) {
				push( @actions,
					'[', ht_a( "$site->{rootp}/clean/$ldir", 'Remove Thumbs' ),
					']', ht_br() );
			}
		}
		elsif ( ! $haveth || ! $havesm || 
				( ! $havemid && $site->{usemidpic} ) ) {
			push( @actions,
				'[', ht_a( "$site->{rootp}/process/$ldir", 'Process Gallery',
						'onClick="alert( \'Please be patient. It may take ' .
						'some time to create the thumbnails.\' )"' ),
				']', ht_br() );
		}
		else {
			push( @actions, 
				'[', ht_a( "$site->{rootp}/process/$ldir", 'Process Gallery',
						'onClick="alert( \'Please be patient. It may take ' .
						'some time to create the thumbnails.\' )"' ),
				'|', ht_a( "$site->{rootp}/clean/$ldir", 'Remove Thumbs' ),
				']', ht_br() );
		}
		
		## Only worry about captions if there are images
		if ( $haveimages ) {
			push( @actions, '[' );

			if ( $site->{advanced} ) {
				push( @actions,
					ht_a( "$site->{rootp}/advcap/$ldir", 'Advanced Caption' ),
					'|' );
			}
			
			if ( $havecap ) {
				push( @actions,
					ht_a( "$site->{rootp}/edit/$ldir", 'Edit Caption' ),
					'|', ht_a( "$site->{rootp}/delete/$ldir", 
						'Delete Caption' ),
					']', ht_br() );
			}
			else {
				push( @actions,
					ht_a( "$site->{rootp}/add/$ldir", 'Add Caption' ),
					']', ht_br() );
			}
		}
		
		push( @lines,
			ht_tr(),
			ht_td( { 'class' => 'dta' }, ht_a( "$site->{rootl}/$ldir",
					"$site->{gallroot}/$ldir" ) ),
			ht_td( { 'class' => 'dta' }, @filelines ),
			ht_td( { 'class' => 'dta' }, @actions ),
			ht_utr(),
			
			ht_tr(),
			ht_td( { 'class' => 'shd', 'colspan' => '3' }, '&nbsp;' ),
			ht_utr() );
	}
	
	return( @lines,
			ht_utable(),
			ht_udiv() );
} # END $site->do_tree
		
#-------------------------------------------------
# $site->do_main( $r, @p )
#-------------------------------------------------
# Directory listing
#-------------------------------------------------
sub do_main {
	my ( $site, $r, @p ) = @_;

	## Prepare the linkage
	my $base			= join( '/', @p );
	pop( @p );
	my $up				= join( '/', @p );
	my $dir				= $site->{gallerydir};
	
	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;

	my $upone			= "$site->{rootp}/main/$up"; 
	$upone				=~ s/\/\//\//g;
	
	## Do this so that we can use it later....
	$base 				.= '/' if ( $base ne '' ); 
	
	$site->{page_title}	.= " $base Contents";

	## If the dir is not valid - we will need to do something else
	if ( ! -e $dir ) {
		return( ht_div( { 'class' => 'error' } ), 
				"Invalid Location: $!", 
				ht_udiv() );
	}

	## See if we should provide the copyright link or not - the functionality
	## will still exist, just won't be apparent how to get there....
	my $copyright = '';
	if ( $site->{copyright} ) {
		$copyright = ' | '. ht_a( "$site->{rootp}/copyright", 'Annotate' );
	}
	
	## Prepare the page
	my @lines = (
		ht_div( { 'class' => 'box' } ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'chdr', 'colspan' => '2' }, 
			'Current Directory: ' . $site->{gallroot} . '/'. $base ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
			ht_a( "$site->{rootp}/tree", 'Tree View' ) ),
		ht_utr(),

		ht_tr(), 
		ht_td( { 'class' => 'hdr' }, 'Subdirectories' ) );
		
	## Up one directory link
	if ( $base ne '' ) {
		push( @lines,
			ht_td( { 'class' => 'rhdr' }, 
				'[', ht_a( $upone, 'Up One' ),
				'|', ht_a( "$site->{fmurl}/main$site->{gallroot}/$base", 
					'FileManager' ),
				$copyright,
				']' ),
			ht_utr() );
	}
	else {
		## If there is a caption for list here, allow for edit, otherwise add
		my @exiffile	= ();

		## EXIF Files
		if ( -e "$site->{gallerydir}/$site->{exiffile}" ) {
			push( @exiffile,
				ht_a( "$site->{rootp}/editexif", 'Edit EXIF' ),
				'|',
				ht_a( "$site->{rootp}/delexif", 'Delete EXIF' ) );
		}
		else {
			push( @exiffile,
				ht_a( "$site->{rootp}/addexif", 'Add EXIF' ) );
		}

		## Put them in the page
		push( @lines,
			ht_td( { 'class' => 'rhdr' }, 
				'[', @exiffile,
				'|', ht_a( "$site->{fmurl}/main$site->{gallroot}/$base", 
						'FileManager' ), ']' ),
			ht_utr() );
	}

	## Grab the listing of the directories
	my @tdirs = File::Find::Rule	-> directory
									-> maxdepth( 1 )
									-> mindepth( 1 )
									-> in( $dir );

	my @dirs = sort { lc( $a ) cmp lc( $b ) } @tdirs;

	if ( ! @dirs ) {
		push( @lines,
			ht_tr(),
			ht_td( { 'class' => 'dta', 'colspan' => '2' }, 
				'No Directories Found' ),
			ht_utr() );
	}

	## See if we have thumbnail dirs - for 'Remove Thumbs'
	my $hasthumbs = 0;

	## Provide directory linkage
	foreach my $ldir ( @dirs ) {
		$ldir =~ s/$dir//;
		$ldir =~ s/^\///;
		chomp( $ldir );

		## Don't link to the thumb directories
		if ( $ldir !~ /$site->{gallthdir}/ && $ldir !~ /$site->{smthdir}/ &&
			$ldir !~ /$site->{midsizedir}/ ) {
			push( @lines,
				ht_tr(),
				ht_td( { 'class' => 'dta' }, 
					ht_a( "$site->{rootp}/main/$base$ldir", "$ldir" ) ) );
		}
		else {
			$hasthumbs++;
			push( @lines,
				ht_tr(),
				ht_td( { 'class' => 'dta' }, $ldir ) );
		}

		if ( $site->{usefilemgr} ) {
			push( @lines,
				ht_td( { 'class' => 'rdta' }, 
					ht_a( "$site->{fmurl}/main$site->{gallroot}/$base$ldir",
						'FileManager' ) ),
				ht_utr() );
		}
		else {
			push( @lines,
				ht_td( { 'class' => 'dta' }, '&nbsp;' ),
				ht_utr() );
		}
	}

	## Grab the listing of all of the files
	my @tfiles = File::Find::Rule	-> file
									-> relative
									-> maxdepth( 1 )
									-> mindepth( 1 )
									-> name( 
										@{$site->{extary}}, 
										$site->{captionfile} )
									-> in( $dir );
	
	my @files = sort { lc( $a ) cmp lc( $b ) } @tfiles;

	push( @lines,
		ht_tr(),
		ht_td( { 'class' => 'hdr' }, 'Files' ) );
	
	## Provide file linkage
	my @filelines = ();
	my $hascap = 0;
	foreach my $lfile ( @files ) {
		$lfile =~ s/$dir//;
		$lfile =~ s/^\///;
		chomp( $lfile );
		
		## Do we have a caption file?
		if ( $lfile eq $site->{captionfile} ) {
			$hascap++;
			next;
		}

		push( @filelines,
			ht_tr(),
			ht_td( { 'class' => 'dta', 'colspan' => '2' }, 
				ht_a( 'javascript://', $lfile, 
					"onClick=\"window.open('$site->{rootp}/show/" .
					"$base/$lfile','Exif Data','height=600,width=800'+'," .
					"screenX='+(window.screenX+150)+',screenY='+" .
					"(window.screenY+100)+',noscrollbars,resizable');\"" ) ),
#				ht_popup( "$site->{rootp}/show/$base$lfile", $lfile, 'Show',
#					'600', '800' ) ),
			ht_utr() );
	}

	## Advanced Captioning - this is set in the config file, not something
	## that we want to leave up to those 'not worthy'...
	my $advcap = '';
	if ( $site->{advanced} ) {
		$advcap = ht_a( "$site->{rootp}/advcap/$base", 'Advanced Caption' ) . 
					' | ';
	}
	
	## Remove Thumbs linkage
	my $removeth = '';
	if ( $hasthumbs ) {
		$removeth = '| ' . 
			ht_a( "$site->{rootp}/clean/$base", 'Remove Thumbs' );
	}

	## Caption files, and everything else....
	if ( $hascap ) {
		## Offer edit and delete for caption file
		push( @lines,
			ht_td( { 'class' => 'rhdr' }, 
				'[', $advcap,
				ht_a( "$site->{rootp}/edit/$base", 'Edit Caption' ),
				'|', ht_a( "$site->{rootp}/delete/$base", 'Delete Caption' ),
				'|', ht_a( "$site->{rootp}/process/$base", 'Process Images',
					'onClick="alert( \'Please be patient. It may take some' .
					'time to create the thumbnails.\' )"' ),
				$removeth,
				']' ),
			ht_utr() );
	}
	else {
		## Offer add for caption file
		push( @lines,
			ht_td( { 'class' => 'rhdr' },
				'[', $advcap,
				ht_a( "$site->{rootp}/add/$base", 'Add Caption' ),
				'|', ht_a( "$site->{rootp}/process/$base", 'Process Images',
					'onClick="alert( \'Please be patient. It may take some' .
					'time to create the thumbnails.\' )"' ),
				$removeth,
				']' ),
			ht_utr() );
	}
	
	if ( ! @filelines ) {
		push( @filelines,
			ht_tr(),
			ht_td( { 'class' => 'dta', 'colspan' => '2' }, 'No Files Found' ),
			ht_utr() );
	}

	return( @lines,
			@filelines,
			ht_utable(),
			ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# caption_checkvals( $site, $in ) 
#-------------------------------------------------
sub caption_checkvals {
	my ( $site, $in ) = @_;

	my @errors;

	## TITLE is not required
	if ( defined $in->{title} && $in->{title} && ! is_text( $in->{title} ) ) {
		push( @errors, 'The', ht_b( 'Title' ), 'must contain',
			'alph-numeric characters.', ht_br() );
	}

	## NUMROW is not required
	if ( defined $in->{numrow} && $in->{numrow} && 
		! is_integer( $in->{numrow} ) ) {
		push( @errors, ht_b( 'Number of Rows' ), 'must be an integer.',
			ht_br() );
	}

	## NUMPAGE is not required
	if ( defined $in->{numpage} && $in->{numpage} &&
		! is_integer( $in->{numpage} ) ) {
		push( @errors, ht_b( 'Number of Pictures/Page' ), 'must be an',
			'integer.', ht_br() );
	}

	## If NUMPAGE and NUMROW are specified, NUMPAGE should divide cleanly by
	## NUMROW - but, we will not 'bother' to check - sometimes, that just
	## doesn't work out....

	## We should, however, make sure that the numbering is sane - there should
	## not be more rows per page than there are pictures on a page
	if ( defined $in->{numpage} && defined $in->{numrow} && 
		$in->{numpage} && $in->{numrow} &&
		is_integer( $in->{numpage} ) && is_integer( $in->{numrow} ) ) {
		if ( $in->{numrow} > $in->{numpage} ) {
			push( @errors, 'There are more rows than there are pictures.',
				ht_br() );
		}
	}

	## ROW is not required
	if ( defined $in->{row} && $in->{row} ) {
		my @lines = split( "\n", $in->{row} );
		foreach my $entry ( @lines ) {
			$entry =~ /^([0-9]*): (.*)$/;
			if ( ! is_integer( $1 ) || ! is_text( $2 ) ) {
				push( @errors, ht_b( 'Row Captions' ), 'must be in the form',
					'of', ht_i( '&lt;Row Number&gt;: &lt;Caption&gt;' ),
					ht_br() );
				last;
			}
		}
	}
	
	## Even pictures are not required, nor their captions
	foreach my $key ( keys %{$in} ) {
		if ( $key =~ /^cap/ ) {
			if ( $in->{$key} && ! is_text( $in->{$key} ) ) {
				push( @errors, 'The', ht_b( 'Image Captions' ), 'must contain',
					'alpha-numeric characters.', ht_br() );
			}
		}
	}

	## GALTHUMB is not required 
	if ( defined $in->{galcap} && $in->{galcap} && 
		! is_text( $in->{galcap} ) ) {
		push( @errors, 'The', ht_b( 'Gallery Caption' ), 'must contain',
			'alpha-numeric characters.', ht_br() );
	}
	
	return( ht_div( { 'class' => 'error' } ),
			ht_h( 1, 'ERRORS' ), 
			@errors,
			ht_udiv() ) if ( @errors );

	return();
} # END caption_checkvals

#-------------------------------------------------
# copyright_checkvals( $site, $in ) 
#-------------------------------------------------
sub copyright_checkvals {
	my ( $site, $in ) = @_;

	my @errors;
	
	## Must define at least an image or a directory
	if ( ! is_text( $in->{image} ) && ! is_text( $in->{dir} ) ) {
		push( @errors, 'You must select either an', ht_b( 'Image File' ),
			'or a', ht_b( 'Directory' ), ht_br() );
	}

	## Can only select either an image or a directory, not both
	if ( is_text( $in->{image} ) && is_text( $in->{dir} ) ) {
		push( @errors, 'You may only select an', ht_b( 'Image File' ),
			'or a', ht_b( 'Directory' ), ', not both', ht_br() );
	}
	
	## text=>string  - required
	if ( ! is_text( $in->{text} ) ) {
		push( @errors, ht_b( 'Text' ), 'must be alpha-numeric', ht_br() );
	}

	## weight=>integer - required
	if ( ! is_integer( $in->{weight} ) ) {
		push( @errors, ht_b( 'Weight' ), 'must be an integer', ht_br() );
	}
	
	## pointsize=>integer - required
	if ( ! is_integer( $in->{pointsize} ) ) {
		push( @errors, ht_b( 'Point Size' ), 'must be an integer', ht_br() );
	}
	
	## fill=>color name - required
	if ( ! is_text( $in->{fill} ) ) {
		push( @errors, ht_b( 'Fill' ), 'must be alpha-numeric', ht_br() );
	}
	
	## family=>string
	if ( defined $in->{family} && $in->{family} && 
		! is_text( $in->{family} ) ) {
		push( @errors, ht_b( 'Family' ), 'must be alpha-numeric', ht_br() );
	}
	
	## strokewidth=>integer
	if ( defined $in->{strokewidth} && $in->{strokewidth} &&
		! is_integer( $in->{strokewidth} ) ) {
		push( @errors, ht_b( 'Stroke Width' ), 'must be an integer',
			ht_br() );
	}
	
	## x=>integer
	if ( defined $in->{x} && $in->{x} && ! is_integer( $in->{x} ) ) {
		push( @errors, ht_b( 'X' ), 'must be an integer', ht_br() );
	}
	
	## y=>integer
	if ( defined $in->{y} && $in->{y} && ! is_integer( $in->{y} ) ) {
		push( @errors, ht_b( 'Y' ), 'must be an integer', ht_br() );
	}
	
	## If we are given one - then need to be given the other
	if ( is_integer( $in->{x} ) && ! is_integer( $in->{y} ) ) {
		push( @errors, 'To provide an', ht_b( 'X' ), ', you need to also',
			'provide a', ht_b( 'Y' ), ht_br() );
	}
	if ( ! is_integer( $in->{x} ) && is_integer( $in->{y} ) ) {
		push( @errors, 'To provide a', ht_b( 'Y' ), ', you need to also',
			'provide an', ht_b( 'X' ), ht_br() );
	}

	## rotate=>float
	if ( defined $in->{rotate} && $in->{rotate} &&
		! is_float( $in->{rotate} ) ) {
		push( @errors,  ht_b( 'Rotate' ), 'must be an integer', ht_br() );
	}
	
	## skewX=>float
	if ( defined $in->{skewX} && $in->{skewX} && ! is_float( $in->{skewX} ) ) {
		push( @errors, ht_b( 'Skew X' ), 'must be a float', ht_br() );
	}
	
	## skewY=> float
	if ( defined $in->{skewY} && $in->{skewY} && ! is_float( $in->{skewY} ) ) {
		push( @errors, ht_b( 'Skew Y' ), 'must be a float', ht_br() );
	}
	
	## If we are given one - then need to be given the other
	if ( is_integer( $in->{skewX} ) && ! is_integer( $in->{skewY} ) ) {
		push( @errors, 'To provide a', ht_b( 'Skew X' ), ', you need to also',
			'provide a', ht_b( 'Skew Y' ), ht_br() );
	}
	if ( ! is_integer( $in->{skewX} ) && is_integer( $in->{skewY} ) ) {
		push( @errors, 'To provide a', ht_b( 'Skew Y' ), ', you need to also',
			'provide a', ht_b( 'Skew X' ), ht_br() );
	}

	return( ht_div( { 'class' => 'error' } ),
			ht_h( 1, 'ERRORS' ),
			@errors,
			ht_udiv() ) if ( @errors );

	return();
} # END copyright_checkvals

#-------------------------------------------------
# caption_form( $site, $in ) 
#-------------------------------------------------
sub caption_form {
	my ( $site, $dir, $in ) = @_;

	my $relative = $dir;
	$relative =~ s/$site->{gallerydir}//;
	$relative =~ s/\/\//\//g;
	
	## If this is do_add - let's give a default for the title
	if ( ! defined $in->{edit} ) {
		$in->{title} = $site->{galtitle};
		if ( $relative ) {
			$in->{title} = $relative;
		}
	}

	## For 'SHOWPICS'
	my @yes = ( 'yes', 'Yes', 'no', 'No' );

	## Start the page
	my @lines = ( 
		ht_form_js( $site->{uri} ),
		ht_div( { 'class' => 'box' } ),
		ht_table(),
		
		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 
			'Caption File Contents - ' . $relative ),
		ht_utr(),

		## TITLE - <text>
		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Gallery Title' ),
		ht_td( { 'class' => 'dta' }, 
			ht_input( 'title', 'text', $in->{title}, 'size="60"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:title' ) ),
		ht_utr(),

		## NUMROW - <integer>
		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Number of Rows/Page' ),
		ht_td( { 'class' => 'dta' }, 
			ht_input( 'numrow', 'text', $in->{numrow}, 'size="3"', 
				'maxlength="2"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:numrow' ) ),
		ht_utr(),
		
		## NUMPAGE - <integer>
		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' },
			'Number of Pictures/Page' ),
		ht_td( { 'class' => 'dta' }, 
			ht_input( 'numpage', 'text', $in->{numpage}, 'size="3"',
				'maxlength="2"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:numpage' ) ),
		ht_utr(),
		
		## ROW<integer> - <text>
		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Row Captions' ),
		ht_td( { 'class' => 'dta' }, 
			ht_input( 'row', 'textarea', $in->{row}, 'rows="6" cols="60"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:row' ) ),
		ht_utr(),

		## SHOWPICS
		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Show Pictures' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'showpic', 1, $in->{showpic}, 0, '', @yes ),
			ht_help( $site->{help}, 'item', 'a:pg:a:showpic' ) ),
		ht_utr() );
			
	## Let's store the html and place it all at once
	my @tlines = ();
	
	## Let's get the list of files - get all of the files from the current
	## directory down
	my @tfiles = File::Find::Rule	-> file
									-> relative
									-> name( @{$site->{extary}} )
									-> in( $dir );

	my @files	= sort { lc( $a ) cmp lc( $b ) } @tfiles;

	## Place all of these files into an array for a select
	my @sfiles	= ( '', 'Select Image', '--BLANK--', '--BLANK--' );
	my @gfiles	= ( '', 'Select Image' );
	
	foreach my $img ( @files ) {
		next if ( $img =~ /\/*$site->{smthdir}\/*/ );
		next if ( $img =~ /\/*$site->{gallthdir}\/*/ );
		next if ( $img =~ /\/*$site->{midsizedir}\/*/ );

		my $name = $img;
		$name =~ s/$dir//;
		$name =~ s/^\///;
		chomp( $name );

		push( @sfiles, $img, $name );

		## The GALTHUMB element should only refer to the local directory
		push( @gfiles, $img, $name ) if ( $img !~ /\// );
	}

	## PIC & GALTHUMB
	## Make sure that numimg is set
	$in->{numimg} = 0 if ( ! defined $in->{numimg} );
	$in->{numimg} = 0 if ( $in->{numimg} < 0 );

	## If we are to add an image, increase the number of numimg
	$in->{numimg}++ if ( defined $in->{addimg} );

	## If we are to del an image, decrease the number of numimg and figure
	## out which in the current order to delete
	my @delorder = ();
	foreach my $key ( keys %{$in} ) {
		if ( $key =~ /^del(\d*)$/ ) {
			push( @delorder, $1 );

			## Keep track of the ones deleted so that they don't show back up
			push( @tlines, 
				ht_input( $key, 'hidden', { $key, $in->{$key} } ) );
		}
	}
	
	## Loop through and create the elements
	my $count = 0;
	for ( my $imgorder = 1; $imgorder <= $in->{numimg}; $imgorder++ ) {

		## If we should delete this one, then skip it - be sure to decrement
		## the numimg as appropriate when all is said and done
		my $skip = 0;
		if ( @delorder ) {
			foreach my $do ( @delorder ) {
				$skip = 1 if ( $imgorder == $do );
			}
		}
		next if ( $skip );

		## Track how many we have to keep numimg up to date
		$count++;
		
		push( @tlines,
			ht_tr(),
			ht_td( { 'class' => 'dta' },
				ht_select( "pic$imgorder", 1, $in->{"pic$imgorder"}, 0, 
					'style="width: 200px;"', @sfiles ) ),
			ht_td( { 'class' => 'dta' },
				ht_input( "cap$imgorder", 'textarea', 
					$in->{"cap$imgorder"}, 'rows="1" cols="30"' ) ), 
			ht_td( { 'class' => 'dta' },
				ht_submit( "del$imgorder", 'Delete Image' ) ),
			ht_utr() );
	}

	## Reset numimg - compensate for deleted images
	$in->{numimg} = $count + scalar( @delorder );

	return( 
		@lines,

		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Gallery Thumbnail' ),
		ht_td( { 'class' => 'dta' },
			ht_table(),
			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'File' ),
			ht_td( { 'class' => 'shd' }, 'Caption', ht_br(),
				ht_help( $site->{help}, 'item', 'a:pg:a:galcaption' ) ),
			ht_utr(),
			
			ht_tr(),
			ht_td( { 'class' => 'dta' },
				ht_select( 'galthumb', 1, $in->{galthumb}, 0,
					'style="width:200px;"', @gfiles ) ),
			ht_td( { 'class' => 'dta' },
				ht_input( 'galcap', 'textarea', $in->{galcap}, 
					'rows="1" cols="30"' ) ),
			ht_utr(),
			ht_utable() ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd', 'width' => '10%' }, 'Pictures' ),
		ht_td( { 'class' => 'dta' },
			ht_table(),
			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'File' ),
			ht_td( { 'class' => 'shd' }, 'Caption', ht_br(),
				ht_help( $site->{help}, 'item', 'a:pg:a:caption' ) ),
			ht_td( { 'class' => 'shd' }, '&nbsp;' ),
			ht_utr(),
			@tlines,
			ht_utable() ),
		ht_utr(),
		
		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
			ht_input( 'numimg', 'hidden', { 'numimg', $in->{numimg} } ),
			ht_submit( 'addimg', 'Add Image' ),
			ht_submit( 'submit', 'Save' ),
			ht_submit( 'cancel', 'Cancel' ) ),
		ht_utr(),
		
		ht_utable(), 
		ht_udiv(), 
		ht_uform() );
} # END caption_form

#-------------------------------------------------
# exif_form( $site, $in )
#-------------------------------------------------
sub exif_form {
	my ( $site, $in ) = @_;

	## We want to pass the user a popup with a test file
	
	return(
		ht_form_js( $site->{uri}, 'name="compose"' ),

		'<script type="text/javascript">',
		'<!--',
		'function SetExif(Tag) {', 
		'  var Form = document.compose.elements[\'text\'];',
		'  if( Form.value.length == 0 || Form.value.indexOf(Tag) == -1 ) {',
		'    if( Form.value.length != 0 ) {' .
		'      Form.value += \'\n\';', 
		'    }', 
		'    Form.value += Tag;',
		'  }', 
		'}',
		'//-->',
		'</script>',

		ht_div( { 'class' => 'box' } ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '2' },
			'Exchangeable Image File (EXIF) Data Attributes' ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
			ht_a( 'javascript://', 'Examples', 
				"onClick=\"window.open('$site->{rootp}/testexif'," .
				"'Exif Data','height=600,width=800'+',screenX='+" .
				"(window.screenX+150)+',screenY='+(window.screenY+100)+'" .
				",noscrollbars,resizable');\"" ) ),
#			ht_popup( "$site->{rootp}/testexif", 'Examples', 'EXIF', '', 
#				'500' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Attributes' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'text', 'textarea', $in->{text}, 'rows="20" cols="60"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:exiftags' ) ),
		ht_utr(),
		
		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
			ht_submit( 'submit', 'Save' ),
			ht_submit( 'cancel', 'Cancel' ) ),
		ht_utr(),

		ht_utable(),
		ht_udiv(),
		ht_uform() );
} # END exif_form

#-------------------------------------------------
# copyright_form( $site, $in )
#-------------------------------------------------
sub copyright_form {
	my ( $site, $in ) = @_;

	## Set up the selects

	## Fonts
	my @tfonts = File::Find::Rule	-> file
									-> relative
									-> name( '*.pfb' )
									-> in( $site->{fontdir} );
	
	my @fonts = sort { lc( $a ) cmp lc( $b ) } @tfonts;

	## Styles
	my @style = (	'Normal', 'Normal',
					'Italic', 'Italic',
					'Oblique', 'Oblique',
					'Any', 'Any' );
			
	## Stretch
	my @stretch = (	'', '--Select Stretch--',
					'Normal', 'Normal',
					'UltraCondensed', 'UltraCondensed',
					'ExtraCondensed', 'ExtraCondensed',
					'Condensed', 'Condensed',
					'SemiCondensed', 'SemiCondensed',
					'SemiExpanded', 'SemiExpanded',
					'Expanded', 'Expanded',
					'ExtraExpanded', 'ExtraExpanded',
					'UltraExpanded', 'UltraExpanded' );

	## Gravity
	my @gravity = (	'NorthWest', 'NorthWest',
					'North', 'North',
					'NorthEast', 'NorthEast', 
					'West', 'West', 
					'Center', 'Center',
					'East', 'East',
					'SouthWest', 'SouthWest',
					'South', 'South',
					'SouthEast', 'SouthEast' );

	## Anti-Alias
	my @antialias = (	'1', 'true',
						'0', 'false' );

	## Align
	my @align = (	'', '--Select Alignment--',
					'Left', 'Left',
					'Center', 'Center',
					'Right', 'Right' );

	## ImageMagick Colors
	## Not sure what's worse - the fact that there are this many defined
	## colors, or... the fact that I actually entered them all in....
	## http://www.imagemagick.org/script/color.php
	my @colors = (	'', '--Select Color--',
					'snow', 'snow', 'snow2', 'snow2',
					'RosyBrown1', 'RosyBrown1', 'RosyBrown2', 'RosyBrown2',
					'snow3', 'snow3', 'LightCoral', 'LightCoral',
					'IndianRed1', 'IndianRed1', 'RosyBrown3', 'RosyBrown3',
					'IndianRed2', 'IndianRed2', 'RosyBrown', 'RosyBrown',
					'brown1', 'brown1', 'firebrick1', 'firebrick1',
					'brown2', 'brown2', 'IndianRed', 'IndianRed',
					'IndianRed3', 'IndianRed3', 'firebrick2', 'firebrick2',
					'snow4', 'snow4', 'brown3', 'brown3', 'red', 'red',
					'red1', 'red1', 'RosyBrown4', 'RosyBrown4',
					'firebrick3', 'firebrick3', 'red2', 'red2',
					'firebrick', 'firebrick', 'brown', 'brown', 'red3', 'red3',
					'IndianRed4', 'IndianRed4', 'brown4', 'brown4',
					'firebrick4', 'firebrick4', 'DarkRed', 'DarkRed',
					'maroon', 'maroon',
					'LightPink1', 'LightPink1', 'LightPink3', 'LightPink3',
					'LightPink4', 'LightPink4', 'LightPink2', 'LightPink2',
					'LightPink', 'LightPink', 'pink', 'pink',
					'crimson', 'crimson', 'pink1', 'pink1', 'pink2', 'pink2',
					'pink3', 'pink3', 'pink4', 'pink4', 
					'PaleVioletRed4', 'PaleVioletRed4', 
					'PaleVioletRed', 'PaleVioletRed',
					'PaleVioletRed2', 'PaleVioletRed2',
					'PaleVioletRed1', 'PaleVioletRed1',
					'PaleVioletRed3', 'PaleVioletRed3',
					'LavenderBlush', 'LavenderBlush',
					'LavenderBlush3', 'LavenderBlush3',
					'LavenderBlush2', 'LavenderBlush2',
					'LavenderBlush4', 'LavenderBlush4', 'maroon', 'maroon',
					'HotPink3', 'HotPink3', 'VioletRed3', 'VioletRed3',
					'VioletRed1', 'VioletRed1', 'VioletRed2', 'VioletRed2',
					'VioletRed4', 'VioletRed4', 'HotPink2', 'HotPink2',
					'HotPink1', 'HotPink1', 'HotPink4', 'HotPink4',
					'HotPink', 'HotPink', 'DeepPink', 'DeepPink',
					'DeepPink2', 'DeepPink2',
					'DeepPink3', 'DeepPink3', 'DeepPink4', 'DeepPink4',
					'maroon1', 'maroon1', 'maroon2', 'maroon2',
					'maroon3', 'maroon3', 'maroon4', 'maroon4',
					'MediumVioletRed', 'MediumVioletRed',
					'VioletRed', 'VioletRed', 'orchid2', 'orchid2',
					'orchid', 'orchid', 'orchid1', 'orchid1',
					'orchid3', 'orchid3', 'orchid4', 'orchid4',
					'thistle1', 'thistle1', 'thistle2', 'thistle2',
					'plum1', 'plum1', 'plum2', 'plum2', 'thistle', 'thistle',
					'thistle3', 'thistle3', 'plum', 'plum', 'violet', 'violet',
					'plum3', 'plum3', 'thistle4', 'thistle4',
					'fuchsia', 'fuchsia', 'plum4', 'plum4',
					'magenta2', 'magenta2', 'magenta3', 'magenta3',
					'DarkMagenta', 'DarkMagenta', 
					'purple', 'purple', 'MediumOrchid', 'MediumOrchid',
					'MediumOrchid1', 'MediumOrchid1', 
					'MediumOrchid2', 'MediumOrchid2',
					'MediumOrchid3', 'MediumOrchid3',
					'MediumOrchid4', 'MediumOrchid4',
					'DarkViolet', 'DarkViolet',
					'DarkOrchid', 'DarkOrchid', 'DarkOrchid1', 'DarkOrchid1',
					'DarkOrchid3', 'DarkOrchid3', 'DarkOrchid2', 'DarkOrchid2',
					'DarkOrchid4', 'DarkOrchid4', 'purple', 'purple',
					'indigo', 'indigo', 'BlueViolet', 'BlueViolet',
					'purple2', 'purple2', 'purple3', 'purple3',
					'purple4', 'purple4', 'purple1', 'purple1',
					'MediumPurple', 'MediumPurple', 
					'MediumPurple1', 'MediumPurple1',
					'MediumPurple2', 'MediumPurple2',
					'MediumPurple3', 'MediumPurple3',
					'MediumPurple4', 'MediumPurple4',
					'DarkSlateBlue', 'DarkSlateBlue',
					'LightSlateBlue', 'LightSlateBlue',
					'MediumSlateBlue', 'MediumSlateBlue',
					'SlateBlue', 'SlateBlue', 'SlateBlue1', 'SlateBlue1',
					'SlateBlue2', 'SlateBlue2', 'SlateBlue3', 'SlateBlue3',
					'SlateBlue4', 'SlateBlue4', 'GhostWhite', 'GhostWhite',
					'lavender', 'lavender', 'blue', 'blue', 'blue2', 'blue2', 
					'MediumBlue', 'MediumBlue', 
					'DarkBlue', 'DarkBlue', 'MidnightBlue', 'MidnightBlue',
					'NavyBlue', 'NavyBlue',
					'RoyalBlue', 'RoyalBlue', 'RoyalBlue1', 'RoyalBlue1',
					'RoyalBlue2', 'RoyalBlue2', 'RoyalBlue3', 'RoyalBlue3',
					'RoyalBlue4', 'RoyalBlue4',
					'CornflowerBlue', 'CornflowerBlue',
					'LightSteelBlue', 'LightSteelBlue',
					'LightSteelBlue1', 'LightSteelBlue1',
					'LightSteelBlue2', 'LightSteelBlue2',
					'LightSteelBlue3', 'LightSteelBlue3',
					'LightSteelBlue4', 'LightSteelBlue4',
					'SlateGray4', 'SlateGray4', 'SlateGray1', 'SlateGray1',
					'SlateGray2', 'SlateGray2', 'SlateGray3', 'SlateGray3',
					'LightSlateGray', 'LightSlateGray',
					'SlateGrey', 'SlateGrey', 'DodgerBlue', 'DodgerBlue',
					'DodgerBlue2', 'DodgerBlue2', 'DodgerBlue4', 'DodgerBlue4',
					'DodgerBlue3', 'DodgerBlue3', 'AliceBlue', 'AliceBlue',
					'SteelBlue4', 'SteelBlue4', 'SteelBlue', 'SteelBlue',
					'SteelBlue1', 'SteelBlue1', 'SteelBlue2', 'SteelBlue2',
					'SteelBlue3', 'SteelBlue3', 'SkyBlue4', 'SkyBlue4',
					'SkyBlue1', 'SkyBlue1', 'SkyBlue2', 'SkyBlue2',
					'SkyBlue3', 'SkyBlue3', 'LightSkyBlue', 'LightSkyBlue',
					'LightSkyBlue4', 'LightSkyBlue4',
					'LightSkyBlue1', 'LightSkyBlue1',
					'LightSkyBlue2', 'LightSkyBlue2',
					'LightSkyBlue3', 'LightSkyBlue3', 'SkyBlue', 'SkyBlue',
					'LightBlue3', 'LightBlue3', 'DeepSkyBlue', 'DeepSkyBlue',
					'DeepSkyBlue2', 'DeepSkyBlue2',
					'DeepSkyBlue4', 'DeepSkyBlue4',
					'DeepSkyBlue3', 'DeepSkyBlue3', 'LightBlue1', 'LightBlue1',
					'LightBlue2', 'LightBlue2', 'LightBlue', 'LightBlue',
					'LightBlue4', 'LightBlue4', 'PowderBlue', 'PowderBlue',
					'CadetBlue1', 'CadetBlue1', 'CadetBlue2', 'CadetBlue2',
					'CadetBlue3', 'CadetBlue3', 'CadetBlue4', 'CadetBlue4',
					'turquoise1', 'turquoise1', 'turquoise2', 'turquoise2',
					'turquoise3', 'turquoise3', 'turquoise4', 'turquoise4',
					'CadetBlue', 'CadetBlue',
					'DarkTurquoise', 'DarkTurquoise', 'azure', 'azure',
					'LightCyan', 'LightCyan', 'azure2', 'azure2',
					'LightCyan2', 'LightCyan2',
					'PaleTurquoise1', 'PaleTurquoise1',
					'PaleTurquoise', 'PaleTurquoise',
					'PaleTurquoise2', 'PaleTurquoise2',
					'DarkSlateGray1', 'DarkSlateGray1', 'azure3', 'azure3',
					'LightCyan3', 'LightCyan3',
					'DarkSlateGray2', 'DarkSlateGray2',
					'PaleTurquoise3', 'PaleTurquoise3',
					'DarkSlateGray3', 'DarkSlateGray3', 'azure4', 'azure4',
					'LightCyan4', 'LightCyan4', 'aqua', 'aqua',
					'PaleTurquoise4', 'PaleTurquoise4',
					'cyan2', 'cyan2', 'DarkSlateGray4', 'DarkSlateGray4',
					'cyan3', 'cyan3', 'DarkCyan', 'DarkCyan',
					'teal', 'teal', 'DarkSlateGray', 'DarkSlateGray',
					'MediumTurquoise', 'MediumTurquoise',
					'LightSeaGreen', 'LightSeaGreen', 'turquoise', 'turquoise',
					'aquamarine4', 'aquamarine4', 'aquamarine', 'aquamarine',
					'aquamarine2', 'aquamarine2',
					'MediumAquamarine', 'MediumAquamarine',
					'MediumSpringGreen', 'MediumSpringGreen',
					'MintCream', 'MintCream', 'SpringGreen', 'SpringGreen',
					'SpringGreen2', 'SpringGreen2',
					'SpringGreen3', 'SpringGreen3',
					'SpringGreen4', 'SpringGreen4',
					'MediumSeaGreen', 'MediumSeaGreen', 'SeaGreen', 'SeaGreen',
					'SeaGreen3', 'SeaGreen3', 'SeaGreen1', 'SeaGreen1',
					'SeaGreen4', 'SeaGreen4', 'SeaGreen2', 'SeaGreen2',
					'MediumForestGreen', 'MediumForestGreen',
					'honeydew', 'honeydew', 'DarkSeaGreen1', 'DarkSeaGreen1',
					'DarkSeaGreen2', 'DarkSeaGreen2',
					'PaleGreen1', 'PaleGreen1', 'PaleGreen', 'PaleGreen',
					'honeydew3', 'honeydew3', 'LightGreen', 'LightGreen',
					'DarkSeaGreen3', 'DarkSeaGreen3',
					'DarkSeaGreen', 'DarkSeaGreen', 'PaleGreen3', 'PaleGreen3',
					'honeydew4', 'honeydew4', 'green', 'green',
					'LimeGreen', 'LimeGreen', 'DarkSeaGreen4', 'DarkSeaGreen4',
					'green2', 'green2', 'PaleGreen4', 'PaleGreen4',
					'green3', 'green3', 'ForestGreen', 'ForestGreen',
					'green4', 'green4', 'green', 'green',
					'DarkGreen', 'DarkGreen', 'LawnGreen', 'LawnGreen',
					'chartreuse', 'chartreuse', 
					'chartreuse2', 'chartreuse2', 'chartreuse3', 'chartreuse3',
					'chartreuse4', 'chartreuse4', 'GreenYellow', 'GreenYellow',
					'DarkOliveGreen3', 'DarkOliveGreen3',
					'DarkOliveGreen1', 'DarkOliveGreen1',
					'DarkOliveGreen2', 'DarkOliveGreen2',
					'DarkOliveGreen4', 'DarkOliveGreen4',
					'DarkOliveGreen', 'DarkOliveGreen', 
					'OliveDrab', 'OliveDrab', 'OliveDrab1', 'OliveDrab1',
					'OliveDrab2', 'OliveDrab2', 
					'YellowGreen', 'YellowGreen', 'OliveDrab4', 'OliveDrab4',
					'ivory', 'ivory', 
					'LightYellow', 'LightYellow', 'beige', 'beige',
					'ivory2', 'ivory2', 
					'LightGoldenrodYellow', 'LightGoldenrodYellow',
					'LightYellow2', 'LightYellow2', 'ivory3', 'ivory3',
					'LightYellow3', 'LightYellow3', 'ivory4', 'ivory4',
					'LightYellow4', 'LightYellow4', 'yellow', 'yellow',
					'yellow2', 'yellow2',
					'yellow3', 'yellow3', 'yellow4', 'yellow4', 
					'olive', 'olive', 'DarkKhaki', 'DarkKhaki',
					'khaki2', 'khaki2', 'LemonChiffon4', 'LemonChiffon4',
					'khaki1', 'khaki1', 'khaki3', 'khaki3', 'khaki4', 'khaki4',
					'PaleGoldenrod', 'PaleGoldenrod',
					'LemonChiffon', 'LemonChiffon', 'khaki', 'khaki',
					'LemonChiffon3', 'LemonChiffon3',
					'LemonChiffon2', 'LemonChiffon2',
					'MediumGoldenRod', 'MediumGoldenRod',
					'cornsilk4', 'cornsilk4', 'gold', 'gold',
					'gold2', 'gold2', 'gold3', 'gold3', 'gold4', 'gold4',
					'LightGoldenrod', 'LightGoldenrod',
					'LightGoldenrod4', 'LightGoldenrod4',
					'LightGoldenrod1', 'LightGoldenrod1',
					'LightGoldenrod3', 'LightGoldenrod3',
					'LightGoldenrod2', 'LightGoldenrod2',
					'cornsilk3', 'cornsilk3', 'cornsilk2', 'cornsilk2',
					'cornsilk', 'cornsilk',
					'goldenrod', 'goldenrod', 'goldenrod1', 'goldenrod1',
					'goldenrod2', 'goldenrod2', 'goldenrod3', 'goldenrod3',
					'goldenrod4', 'goldenrod4', 
					'DarkGoldenrod', 'DarkGoldenrod', 
					'DarkGoldenrod1', 'DarkGoldenrod1',
					'DarkGoldenrod2', 'DarkGoldenrod2',
					'DarkGoldenrod3', 'DarkGoldenrod3',
					'DarkGoldenrod4', 'DarkGoldenrod4',
					'FloralWhite', 'FloralWhite', 'wheat2', 'wheat2',
					'OldLace', 'OldLace', 'wheat', 'wheat', 'wheat1', 'wheat1',
					'wheat3', 'wheat3', 'orange', 'orange', 
					'orange2', 'orange2', 
					'orange3', 'orange3', 'orange4', 'orange4',
					'wheat4', 'wheat4', 'moccasin', 'moccasin',
					'PapayaWhip', 'PapayaWhip', 'NavajoWhite3', 'NavajoWhite3',
					'BlanchedAlmond', 'BlanchedAlmond',
					'NavajoWhite', 'NavajoWhite', 
					'NavajoWhite2', 'NavajoWhite2',
					'NavajoWhite4', 'NavajoWhite4',
					'AntiqueWhite4', 'AntiqueWhite4',
					'AntiqueWhite', 'AntiqueWhite', 'tan', 'tan',
					'bisque4', 'bisque4', 'burlywood', 'burlywood',
					'AntiqueWhite2', 'AntiqueWhite2', 
					'burlywood1', 'burlywood1', 'burlywood3', 'burlywood3',
					'burlywood2', 'burlywood2', 
					'AntiqueWhite1', 'AntiqueWhite1',
					'burlywood4', 'burlywood4',
					'AntiqueWhite3', 'AntiqueWhite3',
					'DarkOrange', 'DarkOrange', 'bisque2', 'bisque2',
					'bisque', 'bisque', 
					'bisque3', 'bisque3', 'DarkOrange1', 'DarkOrange1',
					'linen', 'linen', 'DarkOrange2', 'DarkOrange2',
					'DarkOrange3', 'DarkOrange3', 'DarkOrange4', 'DarkOrange4',
					'peru', 'peru', 'tan1', 'tan1', 'tan2', 'tan2',
					'tan3', 'tan3', 'tan4', 'tan4', 'PeachPuff', 'PeachPuff',
					'PeachPuff4', 'PeachPuff4',
					'PeachPuff2', 'PeachPuff2', 'PeachPuff3', 'PeachPuff3',
					'SandyBrown', 'SandyBrown', 'seashell4', 'seashell4',
					'seashell2', 'seashell2', 'seashell3', 'seashell3',
					'chocolate', 'chocolate', 'chocolate1', 'chocolate1',
					'chocolate2', 'chocolate2', 'chocolate3', 'chocolate3',
					'SaddleBrown', 'SaddleBrown', 'seashell', 'seashell', 
					'sienna4', 'sienna4', 'sienna', 'sienna',
					'sienna1', 'sienna1', 'sienna2', 'sienna2',
					'sienna3', 'sienna3', 'LightSalmon3', 'LightSalmon3',
					'LightSalmon', 'LightSalmon', 
					'LightSalmon4', 'LightSalmon4',
					'LightSalmon2', 'LightSalmon2', 'coral', 'coral',
					'OrangeRed', 'OrangeRed',
					'OrangeRed2', 'OrangeRed2', 'OrangeRed3', 'OrangeRed3',
					'OrangeRed4', 'OrangeRed4', 'DarkSalmon', 'DarkSalmon',
					'salmon1', 'salmon1', 'salmon2', 'salmon2',
					'salmon3', 'salmon3', 'salmon4', 'salmon4',
					'coral1', 'coral1', 'coral2', 'coral2', 'coral3', 'coral3',
					'coral4', 'coral4', 'tomato4', 'tomato4', 
					'tomato', 'tomato',
					'tomato2', 'tomato2', 'tomato3', 'tomato3',
					'MistyRose4', 'MistyRose4', 'MistyRose2', 'MistyRose2',
					'MistyRose', 'MistyRose',
					'salmon', 'salmon', 'MistyRose3', 'MistyRose3',
					'white', 'white', 'grey99', 'grey99',
					'grey98', 'grey98', 'grey97', 'grey97',
					'WhiteSmoke', 'WhiteSmoke', 'grey95', 'grey95',
					'grey94', 'grey94', 'grey93', 'grey93', 'grey92', 'grey92',
					'grey91', 'grey91', 'grey90', 'grey90', 'grey89', 'grey89',
					'grey88', 'grey88', 'grey87', 'grey87',
					'gainsboro', 'gainsboro', 'grey86', 'grey86',
					'grey85', 'grey85', 'grey84', 'grey84', 'grey83', 'grey83',
					'LightGray', 'LightGray', 'gray82', 'gray82',
					'gray81', 'gray81', 'gray80', 'gray80', 'gray79', 'gray79',
					'gray78', 'gray78', 'gray77', 'gray77', 'gray76', 'gray76',
					'silver', 'silver', 'grey75', 'grey75', 'grey', 'grey',
					'grey74', 'grey74', 'grey73', 'grey73', 'grey72', 'grey72',
					'grey71', 'grey71', 'grey70', 'grey70', 'grey69', 'grey69',
					'grey68', 'grey68', 'grey67', 'grey67', 
					'DarkGrey', 'DarkGrey', 'grey66', 'grey66',
					'grey65', 'grey65', 'grey64', 'grey64', 'grey63', 'grey63',
					'grey62', 'grey62', 'grey61', 'grey61', 'grey60', 'grey60',
					'grey59', 'grey59', 'grey58', 'grey58', 'grey57', 'grey57',
					'grey56', 'grey56', 'grey55', 'grey55', 'grey54', 'grey54',
					'grey53', 'grey53', 'grey52', 'grey52', 'grey51', 'grey51',
					'fractal', 'fractal', 'grey50', 'grey50', 'gray', 'gray',
					'grey49', 'grey49', 'grey48', 'grey48', 'grey47', 'grey47',
					'grey46', 'grey46', 'grey45', 'grey45', 'grey44', 'grey44',
					'grey43', 'grey43', 'grey42', 'grey42', 
					'DimGrey', 'DimGrey',
					'grey40', 'grey40', 'grey39', 'grey39', 'grey38', 'grey38',
					'grey37', 'grey37', 'grey36', 'grey36', 'grey35', 'grey35',
					'grey34', 'grey34', 'grey33', 'grey33', 'grey32', 'grey32',
					'grey31', 'grey31', 'grey30', 'grey30', 'grey29', 'grey29',
					'grey28', 'grey28', 'grey27', 'grey27', 'grey26', 'grey26',
					'grey25', 'grey25', 'grey24', 'grey24', 'grey23', 'grey23',
					'grey22', 'grey22', 'grey21', 'grey21', 'grey20', 'grey20',
					'grey19', 'grey19', 'grey18', 'grey18', 'grey17', 'grey17',
					'grey16', 'grey16', 'grey15', 'grey15', 'grey14', 'grey14',
					'grey13', 'grey13', 'grey12', 'grey12', 'grey11', 'grey11',
					'grey10', 'grey10', 'grey9', 'grey9', 'grey8', 'grey8',
					'grey7', 'grey7', 'grey6', 'grey6', 'grey5', 'grey5',
					'grey4', 'grey4', 'grey3', 'grey3', 'grey2', 'grey2',
					'grey1', 'grey1', 'black', 'black', 'none', 'none', 
					'transparent', 'transparent' );

	## Images
	my @files = File::Find::Rule	-> file
									-> relative
									-> name( @{$site->{extary}} )
									-> in( $site->{gallerydir} );

	my @timages = sort { lc( $a ) cmp lc( $b ) } @files;

	my @images = ( '', '--Select Image--' );

	foreach my $f ( @timages ) {
		push( @images, $f, $f );
	}

	## Directories
	my @tdirs = File::Find::Rule	-> directory
									-> relative
									-> not( File::Find::Rule
										-> name(	$site->{smthdir},
													$site->{gallthdir},
													$site->{midsizedir} ) )
									-> in( $site->{gallerydir} );

	my @sdirs = sort { lc( $a ) cmp lc( $b ) } @tdirs;
	
	my @dirs = ( '', '--Select Directory--' );

	foreach my $d ( @sdirs ) {
		push( @dirs, $d, $d );
	}
	
	## Build and return the page
	return( 
		ht_form_js( $site->{uri} ),
		ht_div( { 'class' => 'box' } ),
		ht_table(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '2' }, 'Annotations' ),
		ht_utr(),

		## Image
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Image File' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'image', 1, $in->{image}, 0, '', @images ),
			ht_help( $site->{help}, 'item', 'a:pg:a:imagefile' ) ),
		ht_utr(),
		
		## Directory
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Directory' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'dir', 1, $in->{dir}, 0, '', @dirs ),
			ht_help( $site->{help}, 'item', 'a:pg:a:dirs' ) ),
		ht_utr(),

		## Text - text=>string
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Text' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'text', 'textarea', $in->{text}, 'rows="1" cols="60"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:atext' ) ),
		ht_utr(),
		
		## Font - font=>string
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Font' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'font', 1, $in->{font}, 0, '', @fonts ),
			ht_help( $site->{help}, 'item', 'a:pg:a:font' ) ),
		ht_utr(),
		
		## Family - family=>string
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Family' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'family', 'text', $in->{family}, 'size="60"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:family' ) ),
		ht_utr(),
		
		## Style - style=>{Normal, Italic, Oblique, Any}
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Style' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'style', 1, $in->{style}, 0, '', @style ),
			ht_help( $site->{help}, 'item', 'a:pg:a:style' ) ),
		ht_utr(),
		
		## Stretch - stretch=>{Normal, UltraCondensed, ExtraCondensed, 
		## Condensed, SemiCondensed, SemiExpanded, Expanded, ExtraExpanded, 
		## UltraExpanded}
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Stretch' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'stretch', 1, $in->{stretch}, 0, '', @stretch ),
			ht_help( $site->{help}, 'item', 'a:pg:a:stretch' ) ),
		ht_utr(),

		## Weight - weight=>integer
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Weight' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'weight', 'text', $in->{weight}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:weight' ) ),
		ht_utr(),
		
		## Point Size - pointsize=>integer
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Point Size' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'pointsize', 'text', $in->{pointsize}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:pointsize' ) ),
		ht_utr(),
		
		## Stroke - stroke=> color name
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Stroke Color' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'stroke', 1, $in->{stroke}, 0, '', @colors ),
			ht_help( $site->{help}, 'item', 'a:pg:a:stroke' ) ),
		ht_utr(),
		
		## Stroke Width - strokewidth=>integer
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Stroke Width' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'strokewidth', 'text', $in->{strokewidth}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:strokewidth' ) ),
		ht_utr(),
		
		## Fill - fill=>color name
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Fill Color' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'fill', 1, $in->{fill}, 0, '', @colors ),
			ht_help( $site->{help}, 'item', 'a:pg:a:fill' ) ),
		ht_utr(),
		
		## Under Color - undercolor=>color name
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Under Color' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'undercolor', 1, $in->{undercolor}, 0, '', @colors ),
			ht_help( $site->{help}, 'item', 'a:pg:a:undercolor' ) ),
		ht_utr(),
		
		## Gravity - gravity=>{NorthWest, North, NorthEast, West, Center, 
		## East, SouthWest, South, SouthEast}
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Gravity' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'gravity', 1, $in->{gravity}, 0, '', @gravity ),
			ht_help( $site->{help}, 'item', 'a:pg:a:gravity' ) ),
		ht_utr(),
		
		## Anti-alias - antialias=>{true, false}
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Anti-Alias' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'antialias', 1, $in->{antialias}, 0, '', @antialias ),
			ht_help( $site->{help}, 'item', 'a:pg:a:antialias' ) ),
		ht_utr(),
		
		## X - x=>integer, Y - y=>integer
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'X, Y' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'x', 'text', $in->{x}, 'size="4"' ) .
			',',
			ht_input( 'y', 'text', $in->{y}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:xy' ) ),
		ht_utr(),
		
		## Rotate - rotate=>float
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Rotate' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'rotate', 'text', $in->{rotate}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:rotate' ) ),
		ht_utr(),
		
		## Skew X - skewX=>float, Skew Y - skewY=> float
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Skew X, Skew Y' ),
		ht_td( { 'class' => 'dta' },
			ht_input( 'skewX', 'text', $in->{skewX}, 'size="4"' ) .
			',',
			ht_input( 'skewY', 'text', $in->{skewY}, 'size="4"' ),
			ht_help( $site->{help}, 'item', 'a:pg:a:skew' ) ),
		ht_utr(),
		
		## Align - align=>{Left, Center, Right}
		ht_tr(),
		ht_td( { 'class' => 'shd' }, 'Align' ),
		ht_td( { 'class' => 'dta' },
			ht_select( 'align', 1, $in->{align}, 0, '', @align ),
			ht_help( $site->{help}, 'item', 'a:pg:a:align' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
			ht_submit( 'submit', 'Save' ),
			ht_submit( 'cancel', 'Cancel' ) ),
		ht_utr(),

		ht_utable(),
		ht_udiv(),
		ht_uform() );
} # END copyright_form

# EOF

1;

__END__

=head1 NAME

Alchemy::PhotoGallery - Perl extension for Photo Gallery Management 

=head1 SYNOPSIS

  use Alchemy::PhotoGallery::Admin;

=head1 DESCRIPTION

The administration portion of the PhotoGallery application which
will display an image gallery, or galleries, arranged by directory. It will
use available thumbnails or create them if they do not exist.

=head1 DEPENDENCIES

  Apache2::Request
  File::Find::Rule
  Image::Magick
  Image::ExifInfo
  KrKit::Control
  KrKit::Handler
  KrKit::HTML
  KrKit::Validate

=head1 APACHE

<Location / >
  ## PerlSetVars - Admin Specific
  PerlSetVar  PhotoGallery_ThumbSize    "100"
  PerlSetVar  PhotoGallery_MidSize      "500"
  PerlSetVar  PhotoGallery_SmThSize     "25"
  PerlSetVar  PhotoGallery_ThQual       "20"
  PerlSetVar  PhotoGallery_MidQual      "70"
  PerlSetVar  PhotoGallery_Advanced     "0"
  PerlSetVar  PhotoGallery_Copyright    "1"
  PerlSetVar  PhotoGallery_FontDir      "/usr/share/fonts"    #Required
  PerlSetVar  PhotoGallery_ExifTestImg	"/www/html/fido.jpg'  #Required
  
  PerlSetVar  PhotoGallery_useFM        "1"
  PerlSetVar  PhotoGallery_DirRoot      "/admin/fm"           #Required
  PerlSetVar  PhotoGallery_FilePerm     "0644"
  PerlSetVar  PhotoGallery_DirPerm      "2775"
  PerlSetVar  PhotoGallery_Group        "web"                 #Required
  PerlSetVar  PhotoGallery_chmod        "/bin/chmod"
  PerlSetVar  PhotoGallery_chgrp        "/bin/chgrp"
  
  ## PerlSetVar - General
  PerlSetVar  PhotoGallery_Admin_Root   "/admin/photo"        #Required
  PerlSetVar  PhotoGallery_Root         "/photo"              #Required
  PerlSetVar  PhotoGallery_ImageExt     "jpg jpeg"            #Required
  PerlSetVar  PhotoGallery_Title        "Gallery Index"
  PerlSetVar  PhotoGallery_Dir          "/var/www/html/photo" #Required
  PerlSetVar  PhotoGallery_ThDir        "thumb"
  PerlSetVar  PhotoGallery_SmThDir      "sm_thumb"
  PerlSetVar  PhotoGallery_MidSizeDir   "mid_thumb"
  PerlSetVar  PhotoGallery_ThExt        "_th"
  PerlSetVar  PhotoGallery_SmThExt      "_sm"
  PerlSetVar  PhotoGallery_MidThExt     "_mid"
  PerlSetVar  PhotoGallery_UseMidPic    "0"
  PerlSetVar  PhotoGallery_GalNumRow    "4"
  PerlSetVar  PhotoGallery_GalNumPage   "20"
  PerlSetVar  PhotoGallery_CaptionFile  "caption.txt"
  PerlSetVar  PhotoGallery_ExifFile     "exif_info"
  PerlSetVar  PhotoGallery_ExifFrame    ""
  PerlSetVar  PhotoGallery_FullFrame    ""
  PerlSetVar  PhotoGallery_RTProcess    "0"
</Location>

<Location /admin/photo >
    SetHandler    modperl

    PerlSetVar    SiteTitle    "PhotoGallery Admin"
    
    PerlHandler   Alchemy::PhotoGallery::Admin
</Location>

=head1 VARIABLES

PhotoGallery_ThumbSize

    The maximum default size of the thumbnails - only used for thumbnail 
    generation
	
PhotoGallery_MidSize

    The maximum default size of the midsize thumbnails - only used for 
    thumbnail generation

PhotoGallery_SmThSize

    The maximum default size of the small thumbnails - only used for 
    thumbnail generation

PhotoGallery_ThQual

    Image quality provided to ImageMagick for small thumbnail generation

PhotoGallery_MidQual

    Image quality provided to ImageMagick for midsize thumbnail 
    generation

PhotoGallery_Advanced

    Indicates whether or not an advanced caption or title method should 
	be made available to the user - provides a raw edit capability with 
	no validation...

PhotoGallery_Copyright

    Enables a link to the copyright/annotate functionality - even if the
    link isn't present, the functionality will still exist

PhotoGallery_FontDir

    Provides the name (path) of the directory containing the valid fonts
    for use by Image::Magick - used for doing Annotations

PhotoGallery_ExifTestImg

    The name of the default image for do_testexif to use for sample tags, this
    needs to an absolute path to a file on the local filesystem

PhotoGallery_useFM

    1 indicates use of Alchemy::FileManager in conjunction with the 
    PhotoGallery, 0 indicates to not...

PhotoGallery_DirRoot

    The DirRoot as it is assigned to Alchemy::FileManager

PhotoGallery_FilePerm

    The file permissions to assign to files created by the PhotoGallery

PhotoGallery_DirPerm

    The directory permissions to assign to directories created by the 
    PhotoGallery

PhotoGallery_Group

    The group to assign as owner of files and directories created by the 
    PhotoGallery

PhotoGallery_chmod

    The full path to the chmod program - for updating permissions on 
    files and directories created by the PhotoGallery

PhotoGallery_chgrp

    The full path to the chgrp program - for updating ownership on files
    and directories created by the PhotoGallery

PhotoGallery_Admin_Root 

    The admin root for the application

PhotoGallery_Root

    The viewer root for the application

PhotoGallery_ImageExt

    A list of space delimited extensions identifying the valid image 
    extensions - all other files will be ignored - case-sensitive

PhotoGallery_Title

    The OnPage Title for the application (default, overriden by caption
    file)

PhotoGallery_Dir

    The file path to the gallery directory

PhotoGallery_ThDir

    The name of the Thumbnail directory for each gallery

PhotoGallery_SmThDir

    The name of the Small Thumbnail directory for each gallery

PhotoGallery_MidSizeDir

    The name of the Mid Size Thumbnail direcotry for each gallery

PhotoGallery_ThExt

    The suffix used in the creation of a thumbnail 

PhotoGallery_SmThExt

    The suffix used in the creation of a small thumbnail

PhotoGallery_MidThExt

    The suffix used in the creation of a midsize thumbnail

PhotoGallery_UseMidPic

    1 indicates that the PhotoGallery is to use midpics - between a 
    thumbnail and it's associated original file

PhotoGallery_GalNumRow

    The number of Rows per Page for a gallery

PhotoGallery_GalNumPage

    The number of Images per Page for a gallery

PhotoGallery_CaptionFile

    The name of the caption file to read for each gallery

PhotoGallery_ExifFile

    The name of the EXIF file to read for the EXIF info of an image

PhotoGallery_ExifFrame

    The name of the frame to use for the exif popup (optional)

PhotoGallery_FullFrame

    The name of the frame to use for the show popup (optional)

PhotoGallery_RTProcess

    Indicates real-time processing of the images, advanced

=head1 DATABASE

None by default.

=head1 FUNCTIONS

This module provides the following functions:

$site->do_copyright( $r )

    Provides the capability to add text to an existing image

$site->do_process( $r, @p )

    Processes a gallery 

$site->do_show( $r, $loc )

    Provides a view of an image

$site->do_clean( $r, @p )

    Deletes all the thumb directories in a specific gallery

$site->do_add( $r, @p )

    Adds a caption file

$site->do_edit( $r, @p )

    Edits a caption file

$site->do_delete( $r, @p )

    Deletes a caption file

$site->do_advcap( $r, @p )

    Advanced (Raw) editing of a caption file

$site->do_addexif( $r )

    Adds an EXIF file

$site->do_editexif( $r, @p )

    Edits an EXIF file

$site->do_delexif( $r, @p )

    Delets an EXIF file

$site->do_testexif( $r )

    Provides a way to see and select various EXIF tags for exif_form

$site->do_tree( $r, @p )
	
    Provides the user a comprehensive view of the gallery with admin links
	
$site->do_main( $r, @p )

    Core page of this application

=head1 SEE ALSO

Alchemy::PhotoGallery(3), Alchemy::FileManager(3), KrKit(3), perl(3)

=head1 LIMITATIONS

None defined at this point...

=head1 AUTHOR

Ron Andrews <ron.andrews@cognilogic.net> and Paul Espinosa 
<akson@ericius.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ron Andrews and Paul Espinosa. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.


=cut
