use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Alchemy::PhotoGallery',
    VERSION_FROM      => 'lib/Alchemy/PhotoGallery.pm', # finds $VERSION
    PREREQ_PM         => {
				'KrKit'				=> '0',
				'POSIX'				=> '0',
				'File::Find::Rule'		=> '0',
				'Image::ExifTool'		=> '0',
				'Image::Magick'			=> '0',
#				'Apache2::Request'		=> '0',
			}, 
);
