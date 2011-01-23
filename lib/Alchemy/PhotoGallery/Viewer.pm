package Alchemy::PhotoGallery::Viewer;

use strict;

use POSIX;
use File::Find::Rule;
use Image::ExifTool;
use Image::Magick;

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

#-------------------------------------------------
# $site->do_exif( $r, @p )
#-------------------------------------------------
sub do_exif {
	my ( $site, $r, @p ) = @_;

	my $file		= pop( @p );
	my $base		= join( '/', @p );

	my $picture		= "$site->{gallerydir}/$base/$file";
	$picture		=~ s/\/\//\//g;

	## Update the frame if specified
	$site->{frame}	= $site->{exifframe} if ( $site->{exifframe} );
	
	## Preparations....
	my @exif		= ();
	my @lines		= ();
	my @blanks		= ();
	my $count = 0;

	## Read the EXIF tags from the file, if they exists
	if ( -e "$site->{gallerydir}/$site->{exiffile}" ) {
		open( EXIF, "$site->{gallerydir}/$site->{exiffile}" ) ||
			return( "Can't Open EXIF file: $!\n" );

		while ( my $line = <EXIF> ) {
			$line	=~ s/^\s*//;
			$line	=~ s/\s*$//;

			if ( $line =~ /^$/ ) {
				$blanks[$count] = 1;
			}

			push( @exif, $line );

			$count++;
		}
	}
	else {
		## Default EXIF tags
		@exif		= @{$site->{exiftag}};

	}
	
	$count = 0;

	## Now, if the default is just '--ALL--', then we need to pop it
	## and return to the user, all of the meta-tage found
	@exif			= () if ( $exif[0] eq '--ALL--' );

	## Prep the page
	push( @lines, 
		ht_div( { 'class' => 'exif' } ),
		ht_table(),
		
		ht_tr(),
		ht_td( { 'class' => 'close', 'colspan' => '2' },
			ht_a( 'javascript://', 'Close Window', 
				'onClick="window.close()"' ) ),
		ht_utr(),

		ht_tr(),
		ht_td( { 'class' => 'hdr', 'colspan' => '2' },
			ht_h( '1', 'Exchangeable Image File (EXIF) Data' ) ),
		ht_utr() );
		

	## Prep the object for metadata extraction
	my $exifTool	= new Image::ExifTool;
	$exifTool->Options(	'Unknown' => '1', 
						'Duplicates' => '0' );
	my $info;

	## Grab the data
	if ( @exif ) {
		$info		= $exifTool->ImageInfo( $picture, @exif );
	}
	else {
		$info		= $exifTool->ImageInfo( $picture );
	}
	foreach my $tag ( $exifTool->GetFoundTags() ) {

		if ( defined( $blanks[$count] ) and $blanks[$count] == 1 ) {
			push( @lines,
				ht_tr(),
				ht_td( { 'colspan' => 2, 'class' => 'shd' },
											$site->{exifblank} ),
				ht_utr() );
		}

		my $name	= $exifTool->GetDescription( $tag );
		my $value	= $info->{$tag};
		
		next if ( $name =~ /Directory/i );
		next if ( ref( $value ) eq "SCALAR" );

		if ( is_text( $value ) && $value !~ /^\s*$/ ) {
			push( @lines,
				ht_tr(),
				ht_td( { 'class' => 'shd' }, $name ),
				ht_td( { 'class' => 'dta' }, $value ),
				ht_utr() );
		}

		$count++;
	}

	return( 
		@lines, 
		ht_table(),
		ht_udiv() );
} # END $site->do_exif
		
#-------------------------------------------------
# $site->do_full( $r, @p )
#-------------------------------------------------
sub do_full {
	my ( $site, $r, @p ) = @_;

	my $pic		= pop( @p );
	my $path	= join( '/', @p );
	$path		=~ s/\/\//\//g;

	$site->{page_title} .= " Full Image - $pic";
	
	## Update the frame if specified
	$site->{frame} = $site->{fullframe} if ( $site->{fullframe} );

	if ( ! -e "$site->{gallerydir}/$path/$pic" ) {
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
			ht_td( { 'class' => 'dta' },
				ht_img( "$site->{gallroot}/$path/$pic",
					"title=\"$pic\"",
					"alt=\"$pic\"" ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { 'class' => 'chdr' }, $pic ),
			ht_utr(),

			ht_utable(),
			ht_udiv() );
} # END $site->do_full

#-------------------------------------------------
# $site->do_showphoto( $r, @p )
#-------------------------------------------------
sub do_showphoto {
	my ( $site, $r, @p ) = @_;

	my $fullimage;
	my $pic		= pop( @p );

	if ( $pic eq 'full' ) {
		$fullimage = 1;

		$pic = pop( @p );
	}

	my $base	= join( '/', @p );

	my $dir		= $site->{gallerydir};

	$base		=~ s/^$site->{rootp}//;
	$dir		= "$site->{gallerydir}/$base" if ( $base );
	$dir		=~ s/\/\//\//g;
	$dir		=~ s/\/$//;

	if ( ! -e "$dir/$pic" ) {
		return( ht_div( { 'class' => 'error' } ),
				"Invalid image: $!\n",
				ht_udiv() );
	}

	## This is what we will return
	my @lines;

	## defaults
	my $previmg = '';
	my $nextimg = '';
	my $caption = '';
	
	## If there is a caption file, we only want to show it the way indicated
	if ( -e "$dir/$site->{captionfile}" ) {

		## Let's give it a whirl and see what we get
		my $results = $site->read_caption( $dir, $base );

		## Check for errors
		return( ht_div( { 'class' => 'error' } ),
				'There was an error processing the caption file',
				ht_udiv() ) if ( $results->{error} );

		## Dereference everything we need

		## TITLE
		$site->{page_title} = $results->{title};
		
		## PICS - need prev and next
		my @pics = @{$results->{pictures}};
		my @caps = @{$results->{captions}};
		
		my $found = 0;
		
		if ( $site->{allpics} ) {
			## Now we tend to the gallery at hand - keep in mind, if there are
			## no images, but there are subdirectories - don't provide anything
			my @files = File::Find::Rule	-> file
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> name( @{$site->{extary}} )
											-> in( $dir );

			my @images = sort { lc( $a ) cmp lc( $b ) } @files;

			while ( my $img = shift( @images ) ) {
				my $skip = 0;
				$img	=~ /^(.*)\.(.*)$/;
				my ( $name, $ext ) = ( $1, $2 );

				foreach my $tmpimage ( @pics ) {

					if ( $tmpimage eq $img ) {
						$skip = 1;
					}
				}
				## If there is no thumbnail - then we don't want to show anything
				if ( !$skip ) {
					if ( -e "$dir/$site->{gallthdir}/$name" .
						"$site->{thext}.$ext" ) {
						if ( !$site->{nocap} ) {
							push( @caps, $img );
						}
						else {
							push( @caps, " " );
						}
#						push( @thumbs, "$name$site->{thext}.$ext" );
						push( @pics, $img );
					}
				}
			}
		}
		## Parse the caption file
		for ( my $i = 0; $i < scalar( @pics ); $i++ ) {
			my ( $n, $p ) = ( $i+1, $i-1 );

			if ( $pics[$i] eq $pic ) {
				$caption	= $caps[$i];

				## Need to skip those instances where we have blanks
				## or a slash in the pic name
				my $good	= 0;
				while ( $n < scalar( @pics ) && ! $good ) {
					$n++ if ( ! $pics[$n] );
					$n++ if ( $pics[$n] =~ /\// );
					$good++;
				}
				$nextimg	= $pics[$n];

				$good		= 0;
				while ( $p > 0 && ! $good ) {
					$p-- if ( ! $pics[$p] );
					$p-- if ( $pics[$p] =~ /\// );
					$good++;
				}
				$previmg	= $pics[$p] if ( $i > 0 && $pics[$p] !~ /\// );

				last;
			}
		}
	}
	else {
		## No caption to work from - got to do it manually...
		my @files = File::Find::Rule	-> file
										-> relative
										-> maxdepth( 1 )
										-> mindepth( 1 )
										-> name( @{$site->{extary}},
											$site->{captionfile} )
										-> in( $dir );

		my @images = sort { lc( $a ) cmp lc( $b ) } @files;
		
		## Since none is specifed - modify the page title
		$site->{page_title} = "$base Gallery";

		my $found = 0;
		
		## Find the images
		foreach my $img ( @images ) {
			chomp( $img );

			## Same like the caption file data...
			if ( $img eq $pic ) {
				$found = 1;
				if ( !$site->{nocap} ) {
					$caption = $img;
				}
				else {
					$caption = " ";
				}
	
			}
			elsif ( $found ) {
				## We found it and are looking for the next picture
				$nextimg = $img;
				last;
			}
			else {
				## Nothing, track this as the previmg
				$previmg = $img;
			}
		}
	}

	## Now we have all that we are going to get - as to whether it is all that
	## we need, that remains to be seen....
	## We have (or should have...):
	## $pic, $previmg, $nextimg, $caption
	
	## Prepare the variables
	my $prevth = '';
	if ( $previmg ) {
		$previmg	=~ /^(.*)\.(.*)$/;
		$prevth		= $1 . $site->{smthext} . '.' . $2 if ( $previmg );
	}
	my $nextth = '';
	if ( $nextimg ) {
		$nextimg	=~ /^(.*)\.(.*)$/;
		$nextth		= $1 . $site->{smthext} . '.' . $2 if ( $nextimg );
	}

	## Make the links ready
	if ( $previmg ) {
		$previmg	= "$site->{rootp}/showphoto/$base/$previmg";
		$prevth		= "$site->{gallroot}/$base/$site->{smthdir}/$prevth";
		$previmg	=~ s/\/\//\//g;
		$prevth		=~ s/\/\//\//g;
	}

	if ( $nextimg ) {
		$nextimg	= "$site->{rootp}/showphoto/$base/$nextimg";
		$nextth		= "$site->{gallroot}/$base/$site->{smthdir}/$nextth";
		$nextimg	=~ s/\/\//\//g;
		$nextth		=~ s/\/\//\//g;
	}
	
	## Build the page
	push( @lines,
		ht_div( { 'class' => 'box' } ),

		ht_div( { 'class' => 'invisback' } ),
		ht_div( { 'class' => 'showphoto' } ),
		
		ht_div( { 'class' => 'photoheadl' } ) );

	if ( $previmg ) {
		push( @lines,
			ht_a( $previmg, "$site->{prevtag} " . 
				ht_img( $prevth, 'alt="Previous"', 'title="Previous"' ) ) );
	}
	else {
		push( @lines, '&nbsp;' );
	}

	## Title
	my $titlelnk	= ht_a( "$site->{rootp}/main/$base", $site->{page_title} );
	$titlelnk		=~ s/\/\//\//g;
	
	push( @lines,
		ht_udiv(),
		
		ht_div( { 'class' => 'photoheadc' } ),
		$titlelnk,
		ht_udiv(),
		
		ht_div( { 'class' => 'photoheadr' } ) );
	
	if ( $nextimg ) {
		push( @lines,
			ht_a( $nextimg, ht_img( $nextth, 'alt="Next"', 'title="Next"' ) .
				" $site->{nexttag}" ) );
	}
	else {
		push( @lines, '&nbsp;' );
	}
		
	$site->{exifsize} =~ /^(.*)x(.*)/;
	my ( $xsize, $ysize ) = ( $1, $2 );
	
	## Determine the representation of the photo - if we are using midsize,
	## then display accordinly...
	my $exiflnk		= "$site->{rootp}/exif/$base/$pic";
	my $imglnk		= "$site->{gallroot}/$base/$pic";
	my $midlnk		= "$site->{gallroot}/$base/$site->{midsizedir}";
	$imglnk			=~ s/\/\//\//g;
	$exiflnk		=~ s/\/\//\//g;
	$midlnk			=~ s/\/\//\//g;
	$midlnk			=~ s/\/$//;

	my $exifTool = new Image::ExifTool;
	$exifTool->Options(	'Unknown'		=> '1', 
						'Duplicates'	=> '0' );
	my $info;

	## Grab the data
	$info = $exifTool->ImageInfo(
		"$site->{gallerydir}/$base/$pic", 'Title', 'Description' );

	my $value		= $info->{Title};
	my $description	= $info->{Description};

	if ( defined( $value ) ) {
		chomp( $value );

		$caption = $value;
	}

	if ( defined( $description ) ) {
		chomp( $description );

		$caption = $description;
	}

	my $imglink		= '';
	my @fulllink	= ();

	if ( $site->{usemidpic} && !$fullimage ) {
		$pic =~ /^(.*)\.(.*)$/;
		my $mpic = "$1$site->{midthext}.$2";

		my $path = "$site->{gallerydir}/$base/$site->{midsizedir}/$mpic";
		$path =~ s/\/\//\//g;

		## Buyer beware - what if a midpic wasn't created, then use the old
		## standby - the original
		if ( ! -e $path ) {
			$imglink =
				ht_a( 'javascript://',
					ht_img( $imglnk, 'Click Here', 'title="Exif Data"',
						'alt="Exif Data"' ),
					"onClick=\"window.open('$exiflnk', 'ExifData'," .
					"'height=$ysize,width=$xsize'+',screenX='+" .
					"(window.screenX+150)+',screenY='+(window.screenY+100)+'" .
					",noscrollbars,resizable');\"" );
#			$imglink = ht_popup( $exiflnk,
#				ht_img( $imglnk, 'Click Here', 'title="Exif Data"', 
#					'alt="Exif Data"', "width=\"$site->{midsize}\"" ), 
#					'Exif Data', $ysize, $xsize );
		}
		else {
			$imglink =
				ht_a( 'javascript://',
					ht_img( "$midlnk/$mpic", 'Click Here', 'title="Exif Data"',
						'alt="Exif Data"' ),
					"onClick=\"window.open('$exiflnk', 'ExifData'," .
					"'height=$ysize,width=$xsize'+',screenX='+" .
					"(window.screenX+150)+',screenY='+(window.screenY+100)+'" .
					",noscrollbars,resizable');\"" );
#			$imglink = ht_popup( $exiflnk,
#				ht_img( "$midlnk/$mpic", 'Click Here', 'title="Exif Data"', 
#					'alt="Exif Data"', "width=\"$site->{midsize}\"" ), 
#					'Exif Data', $ysize, $xsize );
		}

		if ( $site->{fullpopup} ) {
			## The link to the full image
			my $full	= "$site->{rootp}/full/$base/$pic";
			$full		=~ s/\/\//\//g;

			push( @fulllink,
				ht_div( { 'class' => 'imagefull' } ),
				ht_a( 'javascript://', 'Full Size Image', 
					"onClick=\"window.open('$full', 'FullSizeImage'," .
					"'height=768,width=1024'+',screenX='+" .
					"(window.screenX+150)+',screenY='+(window.screenY+100)+'" .
					",noscrollbars,resizable');\"" ),
#				ht_popup( $full, 'Full Size Image', 'Full Size Image', '768', 
#					'' ),
				ht_udiv() );
		}
		else {
			## The link to the full image
			my $full	= "$site->{rootp}/showphoto/$base/$pic/full";
			$full		=~ s/\/\//\//g;

			push( @fulllink, 
				ht_div( { 'class' => 'imagefull' } ),
				ht_a( $full, 'Full Size Image' ),
				ht_udiv );
		}
	}
	else {
		$imglink =
			ht_a( 'javascript://',
				ht_img( $imglnk, 'Click Here', 'title="Exif Data"',
					'alt="Exif Data"' ),
				"onClick=\"window.open('$exiflnk', 'ExifData'," .
				"'height=$ysize,width=$xsize'+',screenX='+" .
				"(window.screenX+150)+',screenY='+(window.screenY+100)+'" .
				",noscrollbars,resizable');\"" );
#		$imglink = ht_popup( $exiflnk,
#			ht_img( $imglnk, 'Click Here', 'title="Exif Data"', 
#				'alt="Exif Data"', "width=\"$site->{midsize}\"" ), 
#				'Exif Data', $ysize, $xsize );
	}
	
	## Now the photo and caption
	push( @lines,
		ht_udiv(),
		
		ht_udiv(),

		ht_div( { 'class' => 'image' } ),
		$imglink,
		ht_udiv(),

		@fulllink,

		ht_div( { 'class' => 'photocap' } ),
		$caption,
		ht_udiv() );
		
	return( @lines,
		ht_udiv(),
		ht_udiv() );
} # END do_showphoto
						
#-------------------------------------------------
# $site->do_main( $r, @p )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, @p ) = @_;
	
	## Prepare the linkage
	my ( $page, $base, $dir ) = ( '', '', '' );
	$page			= pop( @p );
	$base			= join( '/', @p );
	$dir			= $site->{gallerydir};

	## This is just a quick check to make sure that we don't mistake
	## a page for a directory (or vice versa)
	my $tempdir		= $dir;
	$tempdir		.= "/$base" if ( $base );

	$tempdir		.= "/$page" if ( $page );

	$tempdir		=~ s/\/\//\//g;

	## No base means we are on page 1
	## If the page is not an integer, it is part of the base
	## Also, initialize the Title - to be overwritten over by a caption file
	if ( ( $base eq '' && ! is_integer( $page ) ) || -d "$tempdir" ) {
		$base .= "/$page" if ( $page );
		$page = 1;

		$site->{page_title} = $site->{galtitle};
	}
	else {
		$site->{page_title} = $base . ' Page';
	}

	$base				=~ s/\/\//\//g;
	$base				=~ s/^\///;
	$dir				= "$site->{gallerydir}/$base" if ( $base );
	$dir				=~ s/\/\//\//g;
	
	## If we are on a page that is not / - Title with the base . Page thing
	if ( $base ne '' ) {
		$site->{page_title} = $base . ' Page';
	}

	## Process the photos... if we are supposed to
	if ( $site->{rtprocess} ) {
		$site->process_photos( $site->{gallerydir} );
	}

	## Get any/all galleries data
	my @lines		= get_gallery( $site, $base, $dir, $page );

	## If we have no galleries to display - then let them know it....
	if ( ! @lines ) {
		return( ht_div( { 'class' => 'noimage' } ),
				'No Galleries are prepared for viewing.',
				ht_udiv() );
	}

	return( ht_div( { 'class' => 'box' } ),
			@lines, 
			ht_udiv() );

} # END $site->do_main

##-----------------------------------------------------------------##
## Support                                                         ##
##-----------------------------------------------------------------##

#-------------------------------------------------
# get_gallery( $site, $base, $dir, $page )
#-------------------------------------------------
sub get_gallery {
	my ( $site, $base, $dir, $page ) = @_;

	## Just because errors aren't pretty....
	$base = '' if ( ! $base );

	## This is all that we will return
	my @lines;

	## Some preparation never hurt....
	my @captions	= ();
	my @thumbs		= ();
	my @pictures	= ();
	my @rowcaps		= ();
	my @gals		= ();
	my @errors		= ();
	my %galhold;

	## Defaults to be overwritten by the caption file
	my $numrow		= $site->{galnumrow};
	my $numpage		= $site->{galnumpage};

	## If there is a caption file, we must build our list based on it
	## be it files or directories

	if ( -e "$dir/$site->{captionfile}" ) {
		## Let's give it whirl and see what we get
		my $results = $site->read_caption( $dir, $base );

		## Check for errors
		return( ht_div( { 'class' => 'error' } ),
				'There was an error processing the caption file',
				ht_udiv() ) if ( $results->{error} );
		
		## If we are to show nothing (SHOWPICS - NO), then return an unprepared
		## gallery
		if ( ! $results->{showpics} ) {
			return( ht_div( { 'class' => 'noimage' } ),
					'There are no galleries to display',
					ht_udiv() );
		}

		## Dereference everything
		$site->{page_title}	= $results->{title}		if ( $results->{title} );
		
		$numrow			= $results->{numrow}	if ( $results->{numrow} );
		$numpage		= $results->{numpage}	if ( $results->{numpage} );

		@thumbs			= @{$results->{thumbs}}		if ( $results->{thumbs} );
		@gals			= @{$results->{gals}}		if ( $results->{gals} );
		@rowcaps		= @{$results->{rowcaps}}	if ( $results->{rowcaps} );
		@captions		= @{$results->{captions}}	
												if ( $results->{captions} );
		@pictures		= @{$results->{pictures}}	
												if ( $results->{pictures} );

		foreach my $gh ( @gals ) {
			$galhold{$gh} = 1;
		}

		## If we are to show all pics, not just the ones specified
		## in the caption file.
		if ( $site->{allpics} ) {
			## Get the subdirectories
			my @subdirs = File::Find::Rule	-> directory
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> not( File::Find::Rule
											-> name(	$site->{smthdir},
														$site->{gallthdir},
														$site->{midsizedir} ) )
											-> in( $dir );

			my @dirs = sort { lc( $a ) cmp lc( $b ) } @subdirs;

			## Loop through the subdirectories and defined the thumbs and
			## captions
			foreach my $item ( @dirs ) {

				## Find the first image we can to show
				my $lpath = "$dir/$item";
				$lpath =~ s/\/\//\//g;
				$lpath =~ s/\/$//;

				my @files = File::Find::Rule	-> file
												-> relative
												-> maxdepth( 1 )
												-> mindepth( 1 )
												-> name( @{$site->{extary}} )
												-> in( $lpath );

				my @images = sort { lc( $b ) cmp lc( $a ) } @files;

				## Track if anything is valid....
				my $hasimg = 0;
				while ( my $img = shift( @images ) ) {
					$img				=~ /^(.*)\.(.*)$/;
					my ( $name, $ext )	= ( $1, $2 );

					## If there is no thumbnail - then, we don't want to
					## show anything
					if ( -e "$lpath/$site->{gallthdir}/$name" .
						"$site->{thext}.$ext" ) {

						if ( !defined( $galhold{"$base/$item"} ) ) {
							unshift( @captions, $item." $site->{galtag}" );
							unshift( @thumbs, "$name$site->{thext}.$ext" );
							unshift( @pictures, "$base/$item/$img" );
							unshift( @gals, "$base/$item" );

						}
						## Yeah, we found one...
						$hasimg++;

						## Since we have the one we need, we are done
						last;
						
					}
				}

				## If we didn't find any images, don't provide a link unless
				## it has subdirectories
				if ( ! @images ) {
					unshift( @captions,	$item );
					unshift( @thumbs,		'No Images' );
					unshift( @pictures,	$item );
					unshift( @gals,		"$base/$item" );
				}
				elsif ( ! $hasimg ) {
					## Loop through the full listing of directories and see
					## if there is a directory with this path and some text
					## following it
					my $something = 0;
					foreach my $test ( @dirs ) {
						if ( $test =~ /^$lpath\/(.*)/ ) {
							if ( $1 =~ /^\S*/ ) {
								## Something
								$something++;
							}
						}
					}
					
					if ( $something ) {
						unshift( @captions,	$item );
						unshift( @thumbs,		'No Images' );
						unshift( @pictures,	$item );
						unshift( @gals,		"$base/$item" );
					}
				}
			}

			## Now we tend to the gallery at hand - keep in mind, if there are
			## no images, but there are subdirectories - don't provide anything
			my @files = File::Find::Rule	-> file
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> name( @{$site->{extary}} )
											-> in( $dir );

			my @images = sort { lc( $a ) cmp lc( $b ) } @files;

			while ( my $img = shift( @images ) ) {

				my $skip = 0;
				$img	=~ /^(.*)\.(.*)$/;
				my ( $name, $ext ) = ( $1, $2 );

				foreach my $tmpimage ( @pictures ) {

					if ( $tmpimage eq $img ) {
						$skip = 1;
					}
				}
				## If there is no thumbnail - then we don't want to show anything

				if ( !$skip ) {
					if ( -e "$dir/$site->{gallthdir}/$name" .
						"$site->{thext}.$ext" ) {
						if ( !$site->{nocap} ) {
							push( @captions, $img );
						}
						else {
							push( @captions, " " );
						}
						push( @thumbs, "$name$site->{thext}.$ext" );
						push( @pictures, $img );
						push( @gals, $base );

					}
				}
			}
		}
	}
	else {
		## Get the subdirectories
		my @subdirs = File::Find::Rule	-> directory
										-> relative
										-> maxdepth( 1 )
										-> mindepth( 1 )
										-> not( File::Find::Rule
											-> name(	$site->{smthdir},
														$site->{gallthdir},
														$site->{midsizedir} ) )
										-> in( $dir );

		my @dirs = sort { lc( $a ) cmp lc( $b ) } @subdirs;

		## Loop through the subdirectories and defined the thumbs and captions
		foreach my $item ( @dirs ) {

			## If there is a caption file, we must build the link from it 
			if ( -e "$dir/$item/$site->{captionfile}" ) {

				## Some temp variables - we don't want the contents of these
				## caption files - overriding those of the current dir
				my ( $caps, $thmbs, $pic, $gls, $error );
				$error = 0;

				## Let's give it whirl and se what we get
				my $results = $site->read_caption( "$dir/$item", $base );

				## Dereference everything we need

				## We need to see if a galthumb is indicated or not, if it is
				## not, we will need to go through the list of thumbs to find
				## the index of the first available picture
				if ( $results->{galthumb} ) {
					my $gpic	= $results->{galthumb};
					$gpic		=~ /(.*)\.(.*)/;
					$gpic		= "$1$site->{thext}.$2";
					$caps		= "$results->{galcap} $site->{galtag}";

					$thmbs		= $gpic;
					$pic		= $results->{galthumb};
					$gls		= $results->{galbase};
				}
				elsif ( @{$results->{thumbs}} ) {
					## Loop through - we need a link to an image in the
					## gallery - not a subdir - if none are found, go ahead
					## and grab the first in the list (based on pictures
					my @tp		= @{$results->{pictures}};

					my $index = 0;
					for ( my $i = 0; $i < scalar( @tp ); $i++ ) {
						next if ( $tp[$i] =~ /\// );
						$index = $i;
						$i = scalar( @tp );
					}

					my @tc		= @{$results->{captions}};
					my @tt		= @{$results->{thumbs}};
					my @tg		= @{$results->{gals}};
					$caps		= "$results->{galcap} $site->{galtag}";

					if ( $caps eq '' ) {
						$caps = $item;
					}
					$thmbs		= $tt[$index];
					$pic		= $tp[$index];
					$gls		= "$tg[$index]/$item";
				}
				else {
					my $lpath = "$dir/$item";
					my @files = File::Find::Rule	-> file
													-> relative
													-> maxdepth( 1 )
													-> mindepth( 1 )
													-> name( @{$site->{extary}} )
													-> in( $lpath );

					my @images = sort { lc( $a ) cmp lc( $b ) } @files;

					my $gpic	= $images[0];
					$pic		= "$gpic";
					$gpic		=~ /(.*)\.(.*)/;
					$caps		= "$item $site->{galtag}";
					$gpic		= "$1$site->{thext}.$2";

					$thmbs		= $gpic;
					$gls		= $item;
				}

				$error	= $results->{error}	if ( $results->{error} );

				## Check for errors
				push( @lines, 
					ht_div( { 'class' => 'errors' } ),
					'There was an error processing the caption file',
					ht_udiv() ) if ( $error );
					
				## All we need is the 'first' element of each
				## If there is something to show... skip this gal if error
				push( @captions,	$caps )if ( $gls && ! $error );
				push( @thumbs,		$thmbs )	if ( $gls && ! $error );
				push( @pictures,	$pic )		if ( $gls && ! $error );

				## Since this is a gal thumb - we need to make sure that the
				## gal directory includes the subdirectory name
				push( @gals,		$gls ) if ( $gls && ! $error);
			}
			else {

				## Find the first image we can to show
				my $lpath = "$dir/$item";
				$lpath =~ s/\/\//\//g;
				$lpath =~ s/\/$//;

				my @files = File::Find::Rule	-> file
												-> relative
												-> maxdepth( 1 )
												-> mindepth( 1 )
												-> name( @{$site->{extary}} )
												-> in( $lpath );

				my @images = sort { lc( $a ) cmp lc( $b ) } @files;

				## Track if anything is valid....
				my $hasimg = 0;
				while ( my $img = shift( @images ) ) {
					$img				=~ /^(.*)\.(.*)$/;
					my ( $name, $ext )	= ( $1, $2 );

					## If there is no thumbnail - then, we don't want to
					## show anything
					if ( -e "$lpath/$site->{gallthdir}/$name" .
						"$site->{thext}.$ext" ) {

						push( @captions, $item." $site->{galtag}" );
						push( @thumbs, "$name$site->{thext}.$ext" );
						push( @pictures, "$base/$item/$img" );
						push( @gals, "$base/$item" );

						## Yeah, we found one...
						$hasimg++;

						## Since we have the one we need, we are done
						last;
					}
				}

				## If we didn't find any images, don't provide a link unless
				## it has subdirectories
				if ( scalar( @images ) < 0 ) {
					push( @captions,	$item );
					push( @thumbs,		'No Images' );
					push( @pictures,	$item );
					push( @gals,		"$base/$item" );
				}
				elsif ( ! $hasimg ) {
					## Loop through the full listing of directories and see
					## if there is a directory with this path and some text
					## following it
					my $something = 0;
					foreach my $test ( @dirs ) {
						if ( $test =~ /^$lpath\/(.*)/ ) {
							if ( $1 =~ /^\S*/ ) {
								## Something
								$something++;
							}
						}
					}
					
					if ( $something ) {
						push( @captions,	$item );
						push( @thumbs,		'No Images' );
						push( @pictures,	$item );
						push( @gals,		"$base/$item" );
					}
				}
			}
		}

		## Now we tend to the gallery at hand - keep in mind, if there are
		## no images, but there are subdirectories - don't provide anything
		my @files = File::Find::Rule	-> file
										-> relative
										-> maxdepth( 1 )
										-> mindepth( 1 )
										-> name( @{$site->{extary}} )
										-> in( $dir );

		my @images = sort { lc( $a ) cmp lc( $b ) } @files;

		while ( my $img = shift( @images ) ) {
			$img	=~ /^(.*)\.(.*)$/;
			my ( $name, $ext ) = ( $1, $2 );

			## If there is no thumbnail - then we don't want to show anything
			if ( -e "$dir/$site->{gallthdir}/$name" .
				"$site->{thext}.$ext" ) {
				if ( !$site->{nocap} ) {
					push( @captions, $img );
				}
				else {
					push( @captions, " " );
				}
				push( @thumbs, "$name$site->{thext}.$ext" );
				push( @pictures, $img );
				push( @gals, $base );
			}
		}
	}

	## Let's clean all of the arrays for double /
	map { s/\/\//\//g => $_ } @captions;
	map { s/\/\//\//g => $_ } @thumbs;
	map { s/\/\//\//g => $_ } @pictures;
	map { s/\/\//\//g => $_ } @gals;

	## If we found no images - return an empty array
	return() if ( ! @thumbs );

	## Figure out the pages count
	my $totpic		= scalar( @thumbs );
	my $totpages	= ceil( $totpic / $numpage ); ## Number of pages total

	$totpages		= 1			if ( $totpages < 1 );

	## Current page - bear in mind, if we aren't on the first, then the
	## cureent page was 'handed' to us
	$page			= $totpages	if ( $page > $totpages );
	
	## Previous and Next page numbers
	my $ppage		= $page - 1;
	my $npage		= $page + 1;

	## Let's figure out what the width of each cell ought to be based on
	## Defaults in the config file
	## If the number of pics per row is less than numpage / numrow - make
	## it equal to the number of pictures
#	my $picsperrow	= ceil( $numpage / $numrow );
	my $picsperrow	= $numrow;
#	$picsperrow		= scalar( @thumbs ) 
#		if ( ceil( $numpage / $numrow ) < $picsperrow );

	$picsperrow		= scalar( @thumbs ) if ( scalar( @thumbs ) < $picsperrow);
	$picsperrow		= 1	if ( $picsperrow < 1 ); ## default of 1

	## Discover the width for each gallery
	my $width		= int( 100 / $picsperrow );

	## So now adjust the totpic based on the rowcount
	$totpic			= ceil( $totpic / $picsperrow ) * $picsperrow;

	## Now let's build the gallery lines (dirlines)
	## Begin the header
	push( @lines,
		ht_table( { 'class' => 'images' } ),
		
		ht_tr() );

	## Title - make the title a link back to the base, if the base = uri, then
	## we should link up a directory, if we are at the top - then let's not
	## provide a lin
	my $titlelnk = '';

	## We are at the top of the gallery - base is nothing
	if ( ! $base ) {
		$titlelnk	= $site->{page_title};
	}
	else {
		## Check the base against the uri, if there is a forward slash
		## following the base - we want to return to the top of the directory
		my $loc		= $site->{uri};
		$loc		=~ s/^$site->{rootp}\/main\/$base//;
		$loc		=~ s/^\///;
		
		if ( $loc ) {
			## A page has been indicated - link to the base
			$titlelnk	= ht_a( "$site->{rootp}/main/$base", 
							$site->{page_title} );
		}
		else {
			## We need to go up a directory - if there is a forward slash in
			## the base, strip off the end, otherwise - go back to the main
			if ( $base =~ /\// ) {
				$base =~ /(.*)\/(.*)$/;
				$titlelnk	= ht_a( "$site->{rootp}/main/$1",
								$site->{page_title} );
			}
			else {
				$titlelnk	= ht_a( "$site->{rootp}/main",
								$site->{page_title} );
			}
		}
	}
	## Clean up the link
	$titlelnk =~ s/\/\//\//g if ( $titlelnk );

	push( @lines,
		ht_td( { 'width' => '100%', 'colspan' => '3' },
			'<h1 class="imageth">',$titlelnk,'</h1>','<h6 class="imageth"> Page ',$page,' of ',$totpages,'</h6>' ) );

	push( @lines,
		ht_utr,
		ht_tr() );

		## Prev Tag
	if ( $page > 1 ) {
		my $plnk	= "$site->{rootp}/main/$base/$ppage";
		$plnk		=~ s/\/\//\//g;
		push( @lines,
			ht_td( { 'class' => 'ppage', 'width' => '20%' },
				ht_a( $plnk, "$site->{prevtag}", 
					'class="ppage"' ) ) );
	}
	else {
		push( @lines,
			ht_td( { 'class' => 'imageth', 'width' => '20%' }, '&nbsp;' ) );
	}

	my $navlinks;
	for ( my $pgcnt = 1; $pgcnt <= $totpages; $pgcnt++ ) {

		my $lnk;
		if ( $pgcnt == $page ) {
			$lnk = "| $pgcnt ";
		}
		else {
			$lnk = '| '.ht_a( "$site->{rootp}/main/$base/$pgcnt", $pgcnt.' ',
									'class="navcel"');
		}

		$navlinks .= $lnk;
	}

	$navlinks .= '|';

	## Page Nav
	if ( $npage <= $totpages ) {
		my $nlnk	= "$site->{rootp}/main/$base/$npage";
		$nlnk		=~ s/\/\//\//g;
		push( @lines,
			ht_td( { 'class' => 'navcel', 'width' => '60%' },
				$navlinks				
					) );
	}
	else {
		push( @lines,
			ht_td( { 'class' => 'imageth', 'width' => '60%' }, '&nbsp;' ) );
	}

	## Next Tag
	if ( $npage <= $totpages ) {
		my $nlnk	= "$site->{rootp}/main/$base/$npage";
		$nlnk		=~ s/\/\//\//g;
		push( @lines,
			ht_td( { 'class' => 'npage', 'width' => '20%' },
				ht_a( $nlnk, "$site->{nexttag}", 
					'class="npage"' ) ) );
	}
	else {
		push( @lines,
			ht_td( { 'class' => 'imageth', 'width' => '20%' }, '&nbsp;' ) );
	}

	## End the header and begin the gallery
	push( @lines,
		ht_utr(),
		
		ht_tr(),
		ht_td( { 'colspan' => '3' } ),
		
		ht_table( { 'class' => 'inimagetable' } ) );
		
	my $caprow		= 0; ## Caption row tracking
	my $rowcount	= 1; ## Track the rowcount for row captions

	## If we are on a page other than the first - then we need to update the 
	## rowcount accordingly
	$rowcount		= ( $page - 1 ) * ( $numrow + 1 );
	$rowcount		= 1 if ( $rowcount < 1 );

	## We need to figure out where to start based on our current page
	## Remember, we need to now where the last page left off
	my $index		= ( $page - 1 ) * $numpage;
	$index			= 0 if ( $index < 1 );
	
	## We will also need to know where to end
	my $end			= $index + $numpage;
	$end			= $totpic if ( $end > $totpic );

	## And so we begin...
	for ( my $i = $index; $i < $end; $i++ ) {

		## Is this a new row?
		if ( $i % $picsperrow == 0 || $i == $index ) {
		
			if ( $site->{rowcaptop} && ! $caprow ) {
				## Add the rowcaption, if there is one
				if ( $rowcaps[$rowcount] ) {
					push( @lines,
						ht_tr(),
						ht_td( { 'class' => 'rowcap', 
							'colspan' => $picsperrow },
							$rowcaps[$rowcount] ),
						ht_utr() );
				}
			}

			push( @lines, ht_tr() );
		}

		if ( $caprow ) {
			if ( $captions[$i] ) {
				push( @lines,
					ht_td( { 'class' => 'imagecap', 'width' => "$width%" },
						$captions[$i] ) );
			}
			else {
				## If they choose not to have a caption/title - so be it...
				push( @lines,
					ht_td( { 'class' => 'imagecap', 'width' => "$width%" },
						'' ) );
			}
		}
		else {
			## If we are here only because of the indexing, we need to make
			## it blank
			if ( ! $thumbs[$i] ) {
				push( @lines,
					ht_td( { 'class' => 'images', 'width' => "$width%" },
						'&nbsp;' ) );
			}
			else {
				## We need to choose our url carefully, if this is a directory
				## to list, we want it to go to main, otherwise, it should
				## go to showphoto
				my $url		= '';
				my $path	= '';
				my $gallery	= '';
				
				## The easiest way to tell is if the picture has a '/'
				if ( $gals[$i] ne $base || $pictures[$i] =~ /\// ) {
					## We need the directory name
					$path		= $pictures[$i];
					$path		=~ s/(.*)\/(.*)$/$1/;

					## Now clean it up for use
					$path		=~ s/^\///;
					$path		=~ s/\/$//;
					$path		= '' if ( $path =~ /^\s*\/\s*$/ );

					## Just in case it turns out the it wasn't the path with
					## a '/', let's double check
					$path		= '' if ( $pictures[$i] !~ /\// );

					## Pull the gallery and have a look
					$gallery	= $gals[$i];
					$gallery	=~ s/^\///;
					$gallery	=~ s/\/$//;

					## If the gallery and the path are identical - we are
					## going to be duplicating the path - clear out the path
					## value
					$path		= '' if ( $gallery eq $path );

					## Now build the url
					$url		= "$site->{rootp}/main/$gals[$i]/$path";
				}
				else {
					$url		= "$site->{rootp}/showphoto/$gals[$i]/" .
									$pictures[$i];
				}

				## Whatever the selection was, clean it up
				$url		=~ s/\/\//\//g;

				if ( $thumbs[$i] eq 'No Images' ) {
	
					## If the file does not exist, then this is just text to
					## display
					push( @lines, 
						ht_td( { 'class' => 'images', 'width' => "$width%" },
							ht_a( $url, $thumbs[$i] ) ) );
				}
				elsif ( $thumbs[$i] eq '--BLANK--' ) {

					## Provide a blank space
					push( @lines,
						ht_td( { 'class' => 'images', 'width' => "$width%" },
							'&nbsp;' ) );
				}
				else {

#					## We need the name of the thumb for the title and alt
#					$thumbs[$i]	=~ /(.*)\..*$/;
#					my $name	= $1;

					## We need the name of the picture for the title and alt
					my $name	= $captions[$i];
					$name =~ s/^ $//;

					$name = $pictures[$i] if ( $name eq '' );

					## Out linkage
					my $imglnk	= "$site->{gallroot}/$gals[$i]/$path/" .
									"$site->{gallthdir}/$thumbs[$i]";
					$imglnk		=~ s/\/\//\//g;

					my $description;

					if ( $captions[$i] eq ' ' or
									( $captions[$i] eq $pictures[$i] ) ) {
						my $exifTool = new Image::ExifTool;
						$exifTool->Options(	'Unknown'		=> '1', 
											'Duplicates'	=> '0' );
						my $info;

						## Grab the data
						$info =
							$exifTool->ImageInfo(
								"$site->{gallerydir}/$base/$pictures[$i]",
										'Title', 'Description');

						my $value		= $info->{Title};
						$description	= $info->{Description};


						if ( defined( $description ) ) {
							chomp( $description );

							if ( $captions[$i] eq ' ' or
								($captions[$i] eq $pictures[$i]) ) {
										$captions[$i] = $description;
							}
						}

						if ( defined( $value ) ) {
							chomp( $value );

							if (  $captions[$i] eq $pictures[$i] ) {
								$captions[$i] = $value;
							}
							$name = $value;
						}

					}
		
					push( @lines,
						ht_td( { 'class' => 'images', 'width' => "$width%" },
							ht_a( $url, 
								ht_img( $imglnk, "title=\"$name\"", 
									"alt=\"$name\"" ) ) ) );
				}
			}
		}

		## Is this the last one for this row?
		if ( $i % $picsperrow == $picsperrow - 1 ) {
			push( @lines, ht_utr() );
			
			if ( ! $site->{rowcaptop} ) {
				## Add the rowcaption, if there is one
				if ( $caprow && $rowcaps[$rowcount] ) {
					push( @lines,
						ht_tr(),
						ht_td( { 'class' => 'rowcap', 
							'colspan' => $picsperrow },
							$rowcaps[$rowcount] ),
						ht_utr() );
				}
			}
			
			## If we are ending a row - then we need to flip the caprow flag
			if ( $caprow ) {
				$caprow	= 0;
				$rowcount++; ## Finished with the caprow - moving to the next
			}
			else {
				$caprow	= 1;
				$i -= $picsperrow;
			}
		}
	}

	## Let's do the navigation one more time - needed for long pages
	push( @lines,
		ht_utable(),
		ht_utd(),
		ht_utr(),
		
		ht_tr() );

	## Prev Tag
	if ( $page > 1 ) {
		push( @lines,
			ht_td( { 'class' => 'ppage', 'width' => '20%' },
				ht_a( "$site->{rootp}/main/$base/$ppage",
					"$site->{prevtag}", 'class="ppage"' ) ) );
	}
	else {
		push( @lines,
			ht_td( { 'class' => 'ppage', 'width' => '20%' }, '&nbsp;' ) );
	}

	## Title Place Holder, we don't really need a reminder
	push( @lines,
		ht_td( { 'class' => 'imageth', 'width' => '60%' }, '&nbsp;' ) );

	## Next Tag
	if ( $npage <= $totpages ) {
		push( @lines,
			ht_td( { 'class' => 'npage', 'width' => '20%' },
				ht_a( "$site->{rootp}/main/$base/$npage",
					"$site->{nexttag}", 'class="npage"' ) ) );
	}
	else {
		push( @lines,
			ht_td( { 'class' => 'npage', 'width' => '20%' }, '&nbsp;' ) );
	}

	return( @lines,
			ht_utr(),
			ht_utable() );
} # END get_gallery

# EOF

1;

__END__

=head1 NAME

Alchemy::PhotoGallery - Perl extension for Photo Gallery Management 

=head1 SYNOPSIS

  use Alchemy::PhotoGallery::Viewer;

=head1 DESCRIPTION

This is an application which will display an image gallery, or 
galleries, arranged by directory.

=head1 APACHE

<Location / >
  ## PerlSetVars - Viewer Specific
  PerlSetVar  PhotoGallery_PrevTag      "<--"
  PerlSetVar  PhotoGallery_NextTag      "-->"
  PerlSetVar  PhotoGallery_RowCapTop	"0"
  PerlSetVar  PhotoGallery_ExifSize     "350x350"
  
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
  PerlSetVar  PhotoGallery_FullPopup    "0"
  PerlSetVar  PhotoGallery_GalNumRow    "4"
  PerlSetVar  PhotoGallery_GalNumPage   "20"
  PerlSetVar  PhotoGallery_CaptionFile  "caption.txt"
  PerlSetVar  PhotoGallery_ExifFile     "exif_info"
  PerlSetVar  PhotoGallery_ExifFrame    ""
  PerlSetVar  PhotoGallery_FullFrame    ""
  PerlSetVar  PhotoGallery_RTProcess    "0"
</Location>

<Location /photo >
    SetHandler    modperl

    PerlSetVar    SiteTitle    "PhotoGallery - "
    
    PerlHandler   Alchemy::PhotoGallery::Viewer
</Location>

=head1 VARIABLES

PhotoGallery_PrevTag

    The text that will be shown prior to the previous page indicator for 
    galleries and prior to the small thumbnails for previous images 
    within a gallery - there is a css tag (prev) in order to replace 
    with an image

PhotoGallery_NextTag

    The text that will be shown prior to the next page indicator for 
    galleries and prior to the small thumbnails for previous images 
    within a gallery - there is a css tag (next) in order to replace 
    with an image

PhotoGallery_RowCapTop

    This boolean indicates whether the Row Caption should go above or
    below it's related row; 0 - below images, 1 - above images

PhotoGallery_ExifSize

    The dimensiions of the Exif popup page - <height>x<width>, example: 
    350x350

PhotoGallery_AdminRoot

    The admin root of the application

PhotoGallery_Root 

    The viewer root of the application

PhotoGallery_ImageExt

    A list of space delimited extensions identifying the valid image 
    extensions - all other files will be ignored - case-sensitive

PhotoGallery_Title

    The title used on a page for the gallery - replaces page_title

PhotoGallery_Dir

    The file path to the gallery directory

PhotoGallery_ThDir

    The name of the Thumbnail directory for each gallery

PhotoGallery_SmThDir

    The name of the Small Thumbnail directory for each gallery

PhotoGallery_MidSizeDir

    The name of the Mid Size Thumbnail directory for each gallery

PhotoGallery_ThExt

    The suffix used in creation of thumbnails

PhotoGallery_SmThExt

    The suffix used in creation of small thumbnails

PhotoGallery_MidThExt

    The suffix used in creation of midsize thumbnails

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

    The name of the frame to use for the Exif data popup window

PhotoGallery_FullFrame
    
    The name of the frame to use for the Full Photo popup window

PhotoGallery_RTProcess

    Indicates real-time processing of the images, advanced

=head1 DATABASE

None by default.

=head1 FUNCTIONS

This module provides the following functions:

$site->do_exif( $r, $dir, $pic )

    Provides the Exchangeable Image File (EXIF) data

$site->do_full( $r, @p )

    Displays a single full image - only used with midpics

$site->do_showphoto( $r, @p )

    Displays individual photos with links to the previous and next (as 
    applicable)

$site->do_main( $r, @p )

    Provides view to the galleries - provides all listings (files and 
    directories)

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
