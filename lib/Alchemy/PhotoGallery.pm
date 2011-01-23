package Alchemy::PhotoGallery;

use strict;

use KrKit::AppBase;
use KrKit::Control;
use KrKit::Validate;
use KrKit::HTML qw( :all );

use vars qw( $VERSION );

##-----------------------------------------------------------------##
## Variables                                                       ##
##-----------------------------------------------------------------##
$VERSION = '0.18';

##-----------------------------------------------------------------##
## Functions                                                       ##
##-----------------------------------------------------------------##
sub _cleanup_app {
	my ( $site, $r ) = @_;

	return();
} # END $site->_cleanup_app

sub _init_app {
	my ( $site, $r ) = @_;

	my @exif_tags			= qw(	Model
									FileName
									DateTimeOriginal
									ImageSize
									FocalLength
									FNumber
									ExposureTime
									ISO
									ExposureProgram
									MeteringMode
									Flash );

	## Admin Specific
	$site->{thumbsize}		= $r->dir_config( 'PhotoGallery_ThumbSize' ) || 
								100;
	$site->{midsize}		= $r->dir_config( 'PhotoGallery_MidSize' ) || 500;
	$site->{smthsize}		= $r->dir_config( 'PhotoGallery_SmThSize' ) || 25;
	$site->{thqual}			= $r->dir_config( 'PhotoGallery_ThQual' ) || 20;
	$site->{midqual}		= $r->dir_config( 'PhotoGallery_MidQual' ) || 70;
	$site->{advanced}		= $r->dir_config( 'PhotoGallery_Advanced' ) || 0;
	$site->{copyright}		= $r->dir_config( 'PhotoGallery_Copyright' ) || 0;
	$site->{fontdir}		= $r->dir_config( 'PhotoGallery_FontDir' );
	$site->{exiftestimg}	= $r->dir_config( 'PhotoGallery_ExifTestImg' ) || 
								'';

	$site->{fmurl}			= $r->dir_config( 'FM_DirRoot' ) || '';
	$site->{usefilemgr}		= $r->dir_config( 'PhotoGallery_UseFM' ) || 1;
	$site->{usefilemgr}		= 0 if ( $site->{fmurl} eq '' );
	$site->{fperm}			= $r->dir_config( 'PhotoGallery_FilePerm' ) || 664;
	$site->{dperm}			= $r->dir_config( 'PhotoGallery_DirPerm' ) || 2775;
	$site->{group}			= $r->dir_config( 'PhotoGallery_Group' ) || 
								'apache';
	$site->{chmod}			= $r->dir_config( 'PhotoGallery_chmod' ) || 
								'/bin/chmod';
	$site->{chgrp}			= $r->dir_config( 'PhotoGallery_chgrp' ) ||
								'/bin/chgrp';

	## Viewer Specific
	$site->{exiftag}		= \@exif_tags;
	$site->{prevtag}		= $r->dir_config( 'PhotoGallery_PrevTag' ) || '';
	$site->{nexttag}		= $r->dir_config( 'PhotoGallery_NextTag' ) || '';
	$site->{exifsize}		= $r->dir_config( 'PhotoGallery_ExifSize' ) || 
								'350x350';
	$site->{rowcaptop}		= 0;
	$site->{rowcaptop}		= 1 
							if ( $r->dir_config( 'PhotoGallery_RowCapTop' ) );
	$site->{allpics}		= $r->dir_config( 'PhotoGallery_AllPics' ) || '';

	## General Tags (Admin and Viewer)
	$site->{uri}			= $r->uri;
#	$site->{roota}			= $r->dir_config( 'PhotoGallery_Admin_Root' );
	$site->{gallroot}			= $r->dir_config( 'PhotoGallery_Root' );
	$site->{rootl}			= $r->dir_config( 'PhotoGallery_Location' );
#	$site->{rootp}			= $r->dir_config( 'PhotoGallery_Root' );
	$site->{rootp}			= $r->location;
	$site->{imageext}		= $r->dir_config( 'PhotoGallery_ImageExt' ) || '';
	$site->{galtitle}		= $r->dir_config( 'PhotoGallery_Title' ) ||
								'Gallery Index';
	$site->{gallerydir}		= $r->dir_config( 'PhotoGallery_Dir' ) || '';
	$site->{gallthdir}		= $r->dir_config( 'PhotoGallery_ThDir' ) || 
								'thumb';
	$site->{smthdir}		= $r->dir_config( 'PhotoGallery_SmThDir' ) || 
								'sm_thumb';
	$site->{midsizedir}		= $r->dir_config( 'PhotoGallery_MidSizeDir' ) || 
								'mid_thumb';
	$site->{thext}			= $r->dir_config( 'PhotoGallery_ThExt' ) || '_th';
	$site->{smthext}		= $r->dir_config( 'PhotoGallery_SmThExt' ) || '_sm';
	$site->{midthext}		= $r->dir_config( 'PhotoGallery_MidThExt' ) ||
								'_mid';
	$site->{usemidpic}		= $r->dir_config( 'PhotoGallery_UseMidPic' ) || 0;
	$site->{fullpopup}		= $r->dir_config( 'PhotoGallery_FullPopup' ) || 0;
	$site->{galnumrow}		= $r->dir_config( 'PhotoGallery_GalNumRow' ) || 4;
	$site->{galnumpage}		= $r->dir_config( 'PhotoGallery_GalNumPage' ) || 20;
	$site->{captionfile}	= $r->dir_config( 'PhotoGallery_CaptionFile' ) ||
								'caption.txt';
	$site->{nocap}			= $r->dir_config( 'PhotoGallery_NoCap' ) || 0;
	$site->{exiffile}		= $r->dir_config( 'PhotoGallery_ExifFile' ) ||
								'exif_info';
	$site->{exifframe}		= $r->dir_config( 'PhotoGallery_ExifFrame' ) || '';
	$site->{fullframe}		= $r->dir_config( 'PhotoGallery_FullFrame' ) || '';
	$site->{rtprocess}		= $r->dir_config( 'PhotoGallery_RTProcess' ) || 0;
	$site->{galtag}			= $r->dir_config( 'PhotoGallery_GalTag' ) || "";
	$site->{exifblank}		= $r->dir_config( 'PhotoGallery_ExifBlankLn' ) ||
																	"<hr>";

	## Create a shortcut for passing into the Find::File::Rule function
	## for extensions
	my @exts;
	push( @exts, 
		split( ' ', lc( $site->{imageext} ) ), 
		split( ' ', uc( $site->{imageext} ) ) );
	map { s/^(.*)/*.$1/g => $_ } @exts;
	$site->{extary}			= \@exts;
	
	return();
} # END $self->_init_app

#-------------------------------------------------
# is_image( $site, $file )
#-------------------------------------------------
sub is_image {
	my ( $site, $file ) = @_;

	## Strip off the file extension
	$file =~ /.*\.(.*)$/;
	my $ext = lc( $1 );

	## Check if the extension is recognized by ImageExt (PerlSetVar)
	return( 0 ) if ( ! is_text( $ext ) );
	return( 1 ) if ( lc( $site->{imageext} ) =~ $ext );

	return( 0 );
} # END is_image

#-------------------------------------------------
# process_photos( $site, $dir )
#-------------------------------------------------
sub process_photos {
	my ( $site, $dir ) = @_;

	my @dirs = ();

	## Get the list of directories and local subdirectories
	@dirs		= File::Find::Rule	-> directory
									-> not(	File::Find::Rule
										-> name(
											$site->{smthdir},
											$site->{gallthdir},
											$site->{midsizedir} ) )
									-> in( $dir );

	## Go through the list of directories
	foreach my $ldir ( @dirs ) {

		## This will hold the list of pictures to create
		my @pictures	= ();
	
		## Clean up dir (just to be safe)
		$ldir =~ s/\/$//;
		chomp( $ldir );
		
		## No caption file - guess we'll have to do it all...
		my @subfiles	= File::Find::Rule	-> file
											-> relative
											-> maxdepth( 1 )
											-> mindepth( 1 )
											-> name( @{$site->{extary}} )
											-> in( $ldir );

		## We should now have images that exist and are valid
		@pictures = sort { lc( $a ) cmp lc( $b ) } @subfiles;

		## Now - pass off to resize photos
    	resize_photos( $site, \@pictures, $ldir ) if ( @pictures );
	}
		
	return();
} # END process_photos

#-------------------------------------------------
# resize_photos( $site, $pic, $dir,  ) 
#-------------------------------------------------
sub resize_photos {
	my ( $site, $pics, $dir ) = @_;

	## Dererference the pics
	my @pictures = @{$pics};

	## Potential directories
	my @resize_dirs = ( $site->{gallthdir}, $site->{smthdir} );
	push( @resize_dirs, $site->{midsizedir} )   if ( $site->{usemidpic} );

	## Potential categories
	my @cats		= ( $site->{thext}, $site->{smthext} );
	push( @cats, $site->{midthext} )			if ( $site->{usemidpic} );

	## Potential Quality
	my @qual		= ( $site->{thqual}, $site->{thqual} );
	push( @qual, $site->{midqual} )			 if ( $site->{usemidpic} );

	## Potential Sizes
	my @rsize	   = ( $site->{thumbsize}, $site->{smthsize} );
	push( @rsize, $site->{midsize} )			if ( $site->{usemidpic} );
					
	my $dir_idx = 0;
	foreach my $rdir ( @resize_dirs ) {

		## Create the resize directories, if they don't already exist 
		if ( ! -e "$dir/$rdir" ) {
			mkdir( "$dir/$rdir" ) ||
				return( ht_div( { 'class' => 'error' } ),
						"Unable to Create $dir/$rdir: $!",
						ht_udiv() );

			## Tend to directory permissions
			system( $site->{chmod}, $site->{dperm}, "$dir/$rdir" );
			system( $site->{chgrp}, $site->{group}, "$dir/$rdir" );
		}

		## Create the thumbnails
		foreach my $img ( @pictures ) {

			## Prepare the image name
			$img =~ /(.*)(\..*)$/;
			my $name = $1 . $cats[$dir_idx] . $2;

			## Create new thumbnails - if they don't already exist...
			if ( ! -e "$dir/$rdir/$name" ) {
				my $image = Image::Magick->new;
				my $error = $image->Read( "$dir/$img" );

				$image->Profile(	name	=> '*', 
									profile => '' );
				$image->Set(		quality => $qual[$dir_idx] );
				$image->Resize(		$rsize[$dir_idx] . 'x' . $rsize[$dir_idx] );
				$image->Write(		"$dir/$rdir/$name" );

				undef( $image );

				## Tend to the file permissions
				system( $site->{chmod}, $site->{fperm}, "$dir/$rdir/$name" );
				system( $site->{chgrp}, $site->{group}, "$dir/$rdir/$name" );
			}
		}

		$dir_idx++;
	}

	return();
} # END resize_photos

#-------------------------------------------------
# read_caption( $site, $dir, $base )
#-------------------------------------------------
sub read_caption {
	my ( $site, $dir, $base ) = @_;

	## Some preparation never hurt....
	my @captions	= ();
	my @thumbs		= ();
	my @pictures	= ();
	my @rowcaps		= ();
	my @gals		= ();
	my @subgals		= ();
	my $errors		= 0;
	my @none		= ();
	my $showpics	= 1;
	my $nocap		= 0;
	my $galthumb	= '';
	my $galcap		= '';
	my $galbase		= '';

	## Defaults to be overwritten by the caption file
	my $numrow		= $site->{galnumrow};
	my $numpage		= $site->{galnumpage};
#	my $title		= $site->{page_title};
	my $title = $base;
	$title =~ s/\/$//;
	$title =~ s/(.*)\///;

	## If there is a caption file, we must build our list based on it
	## be it files or directories
	open( my $caption_file, "<$dir/$site->{captionfile}" ) ||
		warn( "Unable to open caption file: $!\n" );

	## Read it in and set the environment
	while ( my $line = <$caption_file> ) {
		chomp( $line );

		## SHOWPICS
		## If we find a 'SHOWPICS - NO' then return nothing (no galleries
		## found)
		$showpics		= 0 if ( $line =~ /^SHOWPICS - NO/ );

		## TITLE
		if ( $line =~ /^TITLE - (.*)$/ ) {
			$title		= $1;
		}

		## NUMROW
		if ( $line =~ /^NUMROW - (.*)/ ) {
			$numrow		= $1 if ( is_integer( $1 ) );
		}

		## NUMPAGE
		if ( $line =~ /^NUMPAGE - (.*)/ ) {
			$numpage	= $1 if ( is_integer( $1 ) );
		}

		## SUBDIR
		if ( $line =~ /SUBDIR - (.*)/ ) {

			my $subgal = $1;
			chomp( $subgal );
			my $caps;
			my $pic;
			my $gls;
			my $thmbs;
			my $item;
			my $gpic;

			my $results = $site->read_caption( "$dir/$subgal", $subgal );

				if ( $results->{galthumb} ) {
					$gpic	= $results->{galthumb};
					$gpic		=~ /(.*)\.(.*)/;
					$gpic		= "$1$site->{thext}.$2";
					$caps		= $results->{galcap};

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
					$caps		= $results->{galcap};

					if ( $caps eq '' ) {
						$caps = $subgal;
					}
					$gpic		= $tt[$index];
					$pic		= $tp[$index];
#					$gls		= "$tg[$index]/$subgal";
					$gls		= "$base/$subgal";
				}
				else {
					my $lpath = "$dir/$subgal";
					my @files = File::Find::Rule	-> file
													-> relative
													-> maxdepth( 1 )
													-> mindepth( 1 )
													-> name( @{$site->{extary}} )
													-> in( $lpath );

					my @images = sort { lc( $a ) cmp lc( $b ) } @files;

					$gpic	= $images[0];
					$pic		= "$gpic";
					$gpic		=~ /(.*)\.(.*)/;
					if( !$site->{nocap} ) {
						$caps		= $subgal;
					}
					else{
						$caps		= '';
					}
					$gpic		= "$1$site->{thext}.$2";

					$thmbs		= $gpic;
					$gls		= "$base/$subgal";
				}

			push( @gals,		$gls );
			push( @pictures,	$pic );
			push( @thumbs,		$gpic );
			push( @captions,	"$caps<br>$site->{galtag}" );
		}

		## GAL
		if ( $line =~ /^GALTHUMB (.*) - (.*)$/ ) {
			my ( $img, $cap ) = ( $1, $2 );

			$img	=~ /^(.*)\.(.*)$/;
			my ( $name, $ext ) = ( $1, $2 );

			## Let's clean up the name
			$name =~ s/^\///;

			my $file	= "$dir/$img";
			my $thimg	= "$dir/$site->{gallthdir}/$name$site->{thext}." .
							$ext;
			$file		=~ s/\/\//\//g;
			$thimg		=~ s/\/\//\//g;

			## Make sure that it exists
			if ( -e $file && -e $thimg ) { 
				$galthumb	= $img;
				$galcap		= $cap;
				$galbase	= $dir;
				$galbase	=~ s/$site->{gallerydir}\///;
			}
		}

		## PIC
		if ( $line =~ /^PIC (.*) - (.*)$/ ) {
			my ( $img, $cap ) = ( $1, $2 );

			$img		=~ /^(.*)\.(.*)$/;
			my ( $name, $ext ) = ( $1, $2 );

			## Because we may have directories included, we need to strip
			## off the path
			my $loc = '';
			if ( $img =~ /\// ) {
				$img =~ /(.*)\/.*$/;
				$loc = $1 if ( $1 );
			}
			
			## Let's clean up the name
			$name =~ s/$loc//;
			$name =~ s/^\///;
			$name =~ s/\/\//\//g;

			my $file	= "$dir/$img";
			my $thimg	= "$dir/$loc/$site->{gallthdir}/$name$site->{thext}." .
							$ext;
			$file		=~ s/\/\//\//g;
			$thimg		=~ s/\/\//\//g;

			if ( $img =~ /--BLANK--/ ) {
				## This is a blank image, we need to make sure to
				## abide by the directive
				push( @gals,		'' );
				push( @pictures,	'--BLANK--' );
				push( @thumbs,		'--BLANK--' );
				push( @captions,	'' );
			}
			
			if ( -e $file && -e $thimg ) {
				## Must be good enough - let's go with it....
				push( @gals,		$base );
				push( @pictures,	$img );
				push( @thumbs,		"$name$site->{thext}.$ext" );
#				if ( !$site->{nocap} ) {
					push( @captions,	$cap );
#				}
#				else {
#					push( @captions, " " );
#				}
			}
		}

		## ROWCAP
		if ( $line =~ /^ROW([0-9]*) (.*)$/ ) {
			$rowcaps[$1] = $2;
		}
	}

	close( $caption_file ) ||
		warn( "Can't Close $dir caption file: $!\n" );

	## Clean the gals array elements of double slashes
	map { s/\/\//\//g => $_ } @gals;

	my %results;
	$results{error}		= $errors;
	$results{showpics}	= $showpics;
	$results{numrow}	= $numrow;
	$results{numpage}	= $numpage;
	$results{galcap}	= $galcap;
	$results{title}		= $title;
	
	if ( defined( $title ) && ( $title ne '' ) ) {
		$results{galcap}	= $title;
	}
	else {
		$results{galcap}	= $dir;
		$results{galcap}	=~ s/$site->{gallerydir}\///g;
	}

	$results{captions}	= \@captions;
	$results{thumbs}	= \@thumbs;
	$results{pictures}	= \@pictures;
	$results{rowcaps}	= \@rowcaps;
	$results{gals}		= \@gals;
	$results{galthumb}	= $galthumb;
	$results{galbase}	= $galbase;

	return( \%results );
} # END read_caption


# EOF

1;
__END__

=head1 NAME

Alchemy::PhotoGallery - Perl extension for Photo Gallery management

=head1 SYNOPSIS

  use Alchemy::PhotoGallery

=head1 DEPENDENCIES

  ## Admin
  use Apache2::Request
  use File::Find::Rule
  use Image::Magick
  use KrKit::Control
  use KrKit::Handler
  use KrKit::HTML qw( :all )
  use KrKit::Validate
  
  ## Viewer
  use POSIX
  use File::Find::Rule
  use Image::ExifTool
  use Image::Magick
  use KrKit::Control
  use KrKit::Handler
  use KrKit::HTML qw( :all )
  use KrKit::Validate
  
=head1 DESCRIPTION

This is the top level file for the PhotoGallery application which will
display an image gallery, or galleries arranged by directory. This module
also provides functions that are common to both the Admin and Viewer
modules.

=head1 MODULES

Alchemy::PhotoGallery::Viewer

This is an application which will display an image gallery, or galleries,
arranged by directory.

Alchemy::PhotoGallery::Admin

The administration portion of the PhotoGallery application which
will display an image gallery, or galleries, arranged by directory. It 
will use available thumbnails or create them if they do not exist.

=head1 APACHE

See the Admin and Viewer modules for the appropriate configuration 
information

## Note: for the Help System to be active - it must be set up via KrKit 
## See perldoc KrKit::Helper for more information

=head1 DATABASE

None by default

=head1 METHODS

$site->_cleanup_app( $r )

    Called by the core handler to destroy each page request

$site->_init_app( $r )

    Called by the core handler to initialize each page request
  
$site->is_image( $file )

    Called by the Admin and Viewer to make sure that only images are 
    displayed

$site->process_photos( $dir )

	Process a gallery/directory and its subdirectories

$site->resize_photos( $pic, $dir )

	Actually creates thumbnails (and directories) for a specified picture

$site->read_caption( $dir, $base )

    Reads in a specified caption file and returns a hash with the 
    values found

=head1 INPUT FILES

=head2 CAPTION FILES

Caption files allow a user to indicate how a gallery should be displayed.
This feature is provided for each gallery/directory in the entire 
gallery tree. These files can be maintained independent of the 
application of via the admin section. The file contains a list of the 
following attributes (syntax of each is provided below each attribute):

  PIC <path/filename> - <caption>
    Image name and caption - this element is optional - if none are
    declared but the caption file exists, no images (nor the gallery)
    will be presented to the user, path is only necessary if the image
    is not located in the current directory - used for providing an
	entry into subdirectories/subgalleries
	
  TITLE - <text>
    Title of the gallery - this element is optional
	
  NUMROW - <integer>
    The number of rows per page in the gallery - this element is
    optional

  NUMPAGE - <integer>
    The number of pictures per page in the gallery - this element
    is optional

  ROW<integer> - <text>
    A row comment, displayed on the row indicated by the integer 
    (counting from 1 to n from the top of the page) - this element
    is optional

  GALTHUMB <filename> - <text>
    The filename of the thumb to be used when displaying the link for 
    this gallery, the text will be the caption used when the gallery
    thumbnail is displayed in it's parent directory rendering - this 
    element is optional

  SHOWPIC - <YES|NO>
    This indicates whether or not the contents of a gallery should 
    be shown it does not inhibit a caption file from being used for 
    the higher level gallery, but it does inhibit the images from 
    being shown when in that gallery - good for dealing with sub-
    galleries - this element is optional

An example of this file would look like the following (without the 
leading white space):

  NUMROW - 3
  NUMPAGE - 21
  TITLE - My Stay in Florida
  PIC babe10a2.jpg -
  PIC babe10b2.jpg -
  PIC babe1a.jpg -
  ROW1 At the beginning of 1997, the company I worked for sent me and some other co-workers to Ft. Lauderdale for training for about 6 months. These pictures represent the view from my hotel room.
  PIC babe2a.jpg -
  PIC babe3a.jpg-
  PIC babe5a.jpg -
  PIC babe6a2.jpg -
  ROW2 While down in Ft. Lauderdale I had the occasion to visit the beach.  This is a sampling of the lovely ladies that can be seen.
  PIC marina2.jpg - Oleta River State Recreation Area.
  PIC rocket_garden2.jpg - Rocket Garden at Cape Kennedy.
  PIC shuttle1a.jpg - The Space Shuttle.
  PIC yacht2.jpg - A luxurious way to sunbathe.

Notes: 

1. The number of images per row is based on the ceiling of NUMPAGE / 
NUMROW

2. Regardless of length, and the temptation, do not use a carriage 
return in the text of a ROW field

3. All fields are optional

4. Only a single PIC entry is necessary for a gallery to be shown - if 
the file is blank, then nothing will be displayed

=head2 EXIF FILES

Exchangeable Image File (EXIF) Data, also known as the metadata of an 
image file. Exif files, located in the top-most directory of the gallery
(PerlSetVar PhotoGallery_Dir) allows a user to define the EXIF data tags
that they want to have displayed when a photo (full-size photo) is 
clicked on. These files can be maintained independent of the application
of via the admin section. The format of the file is quite simple, it 
contains a list of the  attributes (or tags) that are desired, one per 
line. The following few lines contain an example of the contents of one 
such file (without the leading spaces):

  Model
  FileName
  DateTimeOriginal
  ImageSize
  FocalLength
  FNumber
  ExposureTime
  ISO
  ExposureProgram
  MeteringMode
  Flash

These tags are only displayed if they are found in the file itself. To 
list all of the EXIF tags found in the data, just use the tag '--ALL--',
this must be on the first line of the file. As always, an example:

  --ALL--

This file is optional.

=head1 CSS Tags

The following list of CSS tags are used in the application - see the 
output text for various elements to exploit in order to better 
customize the look and feel of the output.

Viewer CSS Tags
    box        - general container
    error      - error messages
    exif       - EXIF data container
    imageth    - image heading
    imageth2   - image subheading
    imagecap   - image caption
    ppage      - previous page
    npage      - next page
    invisback  - invisible back
    showphoto  - show photo container
    photoheadl - left photo header
    photoheadc - center photo header
    photoheadr - right photo header
    image      - image container
    photocap   - gallery photo caption
    imagefull  - full-size image container
    rowcap     - row caption

Admin CSS Tags
    box        - general container
    hdr        - heading
    chdr       - centered heading
    rhdr       - right-aligned heading
    shd        - subheading
    rshd       - right-aligned subheading
    error      - error message
    dta        - data
    cdta       - centered data
    rdta       - right-aligned data
	
See the admin.css and viewer.css files in the docs/templates directory 
of  the distribution for an example.

=head1 EXPORT

None by default.

=head1 SEE ALSO

Alchemy::PhotoGallery::Viewer(3), Alchemy::PhotoGallery::Admin(3), 
Alchemy::FileManager(3), KrKit(3), perl(3)

=head1 LIMITATIONS

None defined at this point.... 

=head1 AUTHOR

Ron Andrews <ron.andrews@cognilogic.net> and Paul Espinosa 
<akson@ericius.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ron Andrews and Paul Espinosa. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file

=cut
