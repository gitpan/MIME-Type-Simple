package MIME::Type::Simple;

use strict;
use warnings;

use Carp;
use Storable qw( freeze thaw );

use Sub::Exporter -setup => {
    exports => [qw( is_type alt_types ext_from_type ext3_from_type
                    is_ext type_from_ext
                    add_type 
                    clone split_type )],
    groups  => {
        default =>  [ -all ],
    }
};

=head1 NAME

MIME::Type::Simple - MIME Media Types and their file extensions

=begin readme

=head1 REQUIREMENTS

The following non-core modules are required:

  Sub::Exporter

=head1 INSTALLATION

Installation can be done using the traditional Makefile.PL or the newer
Build.PL methods.

Using Makefile.PL:

  perl Makefile.PL
  make test
  make install

(On Windows platforms you should use C<nmake> instead.)

Using Build.PL (if you have Module::Build installed):

  perl Build.PL
  perl Build test
  perl Build install

=end readme

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use MIME::Type::Simple;

  $type = type_from_ext("jpg");        # returns "image/jpeg"

  $ext  = ext_from_type("text/plain"); # returns "txt"  


=head1 DESCRIPTION

This package gives a simple functions for obtaining common file extensions
from MIME types, and from obtaining MIME types from file extensions.

It is also relaxed with respect to having multiple MIME types
associated with a file extension, or multiple extensions associated
with a MIME type.  It is defined this way in the default data, but you
can have it use a system file (e.g. F</etc/mime.types>) alternatively.

By default, there is a functional interface, although you can also use
an object-oriented inteface.

=for readme stop

=head2 Methods

=cut

my $Default; # Pristine copy of __DATA__
my $Work;    # Working copy of __DATA__

# _args, self and args based on 'self' v0.15

=over

=item new

  $o = MIME::Type::Simple->new;

Creates a new object. You may optionally give it a filehandle of a file
with system MIME information, e.g.

  open $f, "/etc/mime.types";
  $o =  MIME::Type::Simple->new( $f );

=cut

sub new {
    my $class = shift;
    my $self  = { types => { }, extens => { }, };

    bless $self, $class;

    if (@_) {
	my $fh = shift;
	return $self->add_types_from_file( $fh );
    }
    else {
	unless (defined $Default) {
	    $Default = $self->add_types_from_file( \*DATA );
	}
	return clone $Default;
    }
}

=begin internal

=item _args

An internal function used to process arguments, based on C<_args> from
the L<self> package.  It also allows one to use it in non-object
oriented mode.

=item self

An internal function used in place of the C<$self> variable.

=item args

An internal function used in place of shifting arguments from stack.

=end internal

=cut

sub _args {
    my $level = 2;
    my @c = ();
    while ( !defined($c[3]) || $c[3] eq '(eval)') {
        @c = do {
            package DB;
            @DB::args = ();
            caller($level);
        };
        $level++;
    }

    my @args = @DB::args;
    
    if (ref($args[0]) ne __PACKAGE__) {
	unless (defined $Work) {
	    $Work = __PACKAGE__->new();
	}
	unshift @args, $Work;
    }

    return @args;
}

sub self {
    (_args)[0];
}

sub args {
    my @a = _args;
    return @a[1..$#a];
}


=item add_types_from_file

  $o->add_types_from_file( $filehandle );

Imports types from a file. Called by L</new> when a filehandle is
specified.

=cut

sub add_types_from_file {
    my ($fh) = args;

    while (my $line = <$fh>) {
	$line =~ s/^\s+//;
	$line =~ s/\#.*$//;
	$line =~ s/\s+$//;

	if ($line) {
	    self->add_type(split /\s+/, $line); 
	}	
    }
    return self;
}

=item is_type

  if (is_type("text/plain")) { ... }

  if ($o->is_type("text/plain")) { ... }

Returns a true value if the type is defined in the system.

Note that a true value does not necessarily indicate that the type
has file extensions associated with it.

=begin internal

Currently it returns a reference to a list of extensions associated
with that type.  This is for convenience, and may change in future
releases.

=end internal

=cut

sub is_type {
    my ($type) = args;
    my ($cat, $spec)  = split_type($type);
    return self->{types}->{$cat}->{$spec};
}

=item alt_types

  @alts = alt_types("image/jpeg");

  @alts = $o->alt_types("image/jpeg");

Returns alternative or related MIME types that are defined in the system
For instance,

  alt_types("model/dwg")

returns the list

  image/vnd.dwg

=begin internal

=item _normalise

=item _add_aliases

=end internal

=cut

{

    # Some known special cases (keys are normalised). Not exhaustive.

    my %SPEC_CASES = (
       "application/cdf"    => [qw( application/netcdf )],
       "application/dms"    => [qw( application/octet-stream )],
       "application/x-java-source" => [qw( text/plain )],
       "application/java-vm" => [qw( application/octet-stream )],
       "application/lha"    => [qw( application/octet-stream )],
       "application/lzh"    => [qw( application/octet-stream )],
       "application/mac-binhex40"  => [qw( application/binhex40 )],
       "application/msdos-program" => [qw( application/octet-stream )],
       "application/ms-pki.seccat" => [qw( application/vnd.ms-pkiseccat )],
       "application/ms-pki.stl"    => [qw( application/vnd.ms-pki.stl )],
       "application/ndtcdf"  => [qw( application/cdf )],
       "application/netfpx" => [qw( image/vnd.fpx image/vnd.net-fpx )],
       "image/fpx"          => [qw( application/vnd.netfpx image/vnd.net-fpx )],
       "image/netfpx"       => [qw( application/vnd.netfpx image/vnd.fpx )],
       "text/c++hdr"        => [qw( text/plain )],
       "text/c++src"        => [qw( text/plain )],
       "text/chdr"          => [qw( text/plain )],
       "text/fortran"       => [qw( text/plain )],
    ); 


  sub _normalise {
      my $type = shift;
      my ($cat, $spec)  = split_type($type);

      # We "normalise" the type

      $cat  =~ s/^x-//;
      $spec =~ s/^(x-|vnd\.)//;

      return ($cat, $spec);
  }

  sub _add_aliases {
      my @aliases = @_;
      foreach my $type (@aliases) {
	  my ($cat, $spec)  = _normalise($type);
	  $SPEC_CASES{"$cat/$spec"} = \@aliases;
      }
  }

    _add_aliases(qw( application/json text/json ));
    _add_aliases(qw( application/cals-1840 image/cals-1840 image/cals image/x-cals application/cals ));
    _add_aliases(qw( application/mac-binhex40 application/binhex40 ));
    _add_aliases(qw( application/atom+xml application/atom ));
    _add_aliases(qw( application/fractals image/fif ));
    _add_aliases(qw( model/vnd.dwg image/vnd.dwg image/x-dwg application/acad ));
    _add_aliases(qw( image/vnd.dxf image/x-dxf application/x-dxf application/vnd.dxf ));
    _add_aliases(qw( text/x-c text/csrc ));
    _add_aliases(qw( application/x-helpfile application/x-winhlp ));
    _add_aliases(qw( application/x-tex text/x-tex ));
    _add_aliases(qw( application/rtf text/rtf ));
    _add_aliases(qw( image/jpeg image/pipeg image/pjpeg ));
    _add_aliases(qw( text/javascript text/javascript1.0 text/javascript1.1 text/javascript1.2 text/javascript1.3 text/javascript1.4 text/javascript1.5 text/jscript text/livescript text/x-javascript text/x-ecmascript aplication/ecmascript application/javascript ));


    sub alt_types {
	my ($type) = args;
	my ($cat, $spec)  = _normalise($type);

	my %alts  = ( );
	my @cases = ( "$cat/$spec", "$cat/x-$spec", "x-$cat/x-$spec", 
		      "$cat/vnd.$spec" );

	push @cases, @{ $SPEC_CASES{"$cat/$spec"} },
  	  if ($SPEC_CASES{"$cat/$spec"});

	foreach ( @cases ) {
	    $alts{$_} = 1, if (self->is_type($_));
	}

	return (sort keys %alts);
    }
}

=item ext_from_type

  $ext  = ext_from_type( $type );

  @exts = ext_from_type( $type );

  $ext  = $o->ext_from_type( $type );

  @exts = $o->ext_from_type( $type );

Returns the file extension(s) associated with the given MIME type.
When called in a scalar context, returns the first extension from the
list.

The order of extensions is based on the order that they occur in the
source data (either the default here, or the order added using
L</add_types_from_file> or calls to L</add_type>).

=cut

sub ext_from_type {
    if (my $exts = self->is_type(args)) {
	return (wantarray ? @$exts : $exts->[0]);
    }
    else {
	return;
    }
}

=item ext3_from_type

Like L</ext_from_type>, but only returns file extensions under three
characters long.

=cut

sub ext3_from_type {
    my @exts = grep( (length($_) <= 3), (ext_from_type(@_)));
    return (wantarray ? @exts : $exts[0]);
}

=item is_ext

  if (is_ext("image/jpeg")) { ... }

  if ($o->is_type("image/jpeg")) { ... }

Returns a true value if the extension is defined in the system.

=begin internal

Currently it returns a reference to a list of types associated
with that extension.  This is for convenience, and may change in future
releases.

=end internal

=cut

sub is_ext {
    my ($ext)  = args;
    if (exists self->{extens}->{$ext}) {
	return self->{extens}->{$ext};
    }
    else {
	return;
    }
}

=item type_from_ext

  $type  = type_from_ext( $extension );

  @types = type_from_ext( $extension );

  $type  = $o->type_from_ext( $extension );

  @types = $o->type_from_ext( $extension );

Returns the MIME type(s) associated with the extension.  When called
in a scalar context, returns the first type from the list.

The order of types is based on the order that they occur in the
source data (either the default here, or the order added using
L</add_types_from_file> or calls to L</add_type>).

=cut

sub type_from_ext {
    my ($ext)  = args;

    if (my $ts = self->is_ext($ext)) {	
	my @types = map { $_ } @$ts;
	return (wantarray ? @types : $types[0]);
    }
    else {
	croak "Unknown extension: $ext";
    }
}

=begin internal

=item split_type

  ($content_type, $subtype) = split_type( $type );

This is a utlity function for splitting content types.

=end internal

=cut

sub split_type {
    my $type = shift;
    my ($cat, $spec)  = split /\//,  $type;
    return ($cat, $spec);
}

=item add_type

  $o->add_type( $type, @extensions );

Add a type to the system, with an optional list of extensions.

=cut

sub add_type {
    my ($type, @exts) = args;

    my ($cat, $spec)  = split_type($type);

    if (!self->{types}->{$cat}->{$spec}) {
	self->{types}->{$cat}->{$spec} = [ ];
    }
    push @{ self->{types}->{$cat}->{$spec} }, @exts;

    
    foreach (@exts) {
	self->{extens}->{$_} = [] unless (exists self->{extens}->{$_});
	push @{self->{extens}->{$_}}, $type 
    }
}

=item clone

  $c = $o->clone;

Returns a clone of a MIME::Type::Simple object. This allows you to add
new types via L</add_types_from_file> or L</add_type> without affecting
the original.

This can I<only> be used in the object-oriented interface.

=cut

sub clone {
    my $self = shift;
    croak "Expected instance" if (ref($self) ne __PACKAGE__);
    return thaw( freeze $self );
}

=back

=for readme continue

=head1 REVISION HISTORY

For a detailed history see the F<Changes> file included in this distribution.

=head1 SEE ALSO

The L<MIME::Types> module has a similar functionality, but a much more
complex interface.

An "official" list of Media Types can be found at
L<http://www.iana.org/assignments/media-types>.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head2 Suggestions and Bug Reporting

Feedback is always welcome.  Please use the CPAN Request Tracker at
L<http://rt.cpan.org> to submit bug reports.

=head1 ACKNOWLEDGEMENTS

Some of the code comes from L<self> module (by Kang-min Liu).  The data
for the MIME types is based on the Debian mime-support package,
L<http://packages.debian.org/mime-support>,
although with I<many> changes from the original.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Rothenberg, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;


__DATA__
application/activemessage
application/andrew-inset			ez
application/applefile
application/atom+xml				atom
application/atomcat+xml				atomcat
application/atomserv+xml			atomsrv
application/atomicmail
application/auth-policy+xml
application/batch-smtp
application/beep+xml
application/cals-1840                           cal
application/cap					cap pcap
application/ccxml+xml
application/cnrp+xml
application/commonground
application/conference-info+xml
application/cpl+xml
application/csta+xml
application/cstadata+xml
application/cu-seeme				cu
application/cybercash
application/davmount+xml
application/dca-rft
application/dec-dx
application/dns
application/docbook+xml
application/dsptype				tsp
application/dvcs
application/ecmascript
application/edi-consent
application/edifact
application/edi-x12
application/edifact
application/emma+xml
application/envoy                               evy
application/eshop
application/example
application/fastinfoset
application/fastsoap
application/fits
application/font-tdpfr
application/fractals                            fif
application/futuresplash			spl
application/ghostview
application/h224
application/hta					hta
application/http
application/hyperstudio
application/ibe-key-request+xml
application/ibe-pkg-reply+xml
application/ibe-pp-data
application/iges
application/im-iscomposing+xml
application/index
application/index.cmd
application/index.obj
application/index.response
application/index.vnd
application/internet-property-stream            acx
application/iotp
application/ipp
application/isup
application/java-archive			jar
application/java-serialized-object		ser
application/java-vm				class
application/json
application/kpml-request+xml
application/kpml-response+xml
application/lost+xml
application/mac-binhex40			hqx
application/mac-compactpro			cpt
application/macwriteii
application/marc
application/mathematica				nb
application/mathematica-old
application/ms-tnef
application/msaccess				mdb
application/msword				doc dot
application/news-message-id
application/news-transmission
application/ocsp-request
application/ocsp-response
application/octet-stream			bin
application/oda					oda
application/ogg					ogg ogx
application/parityfec
application/pdf					pdf
application/x-perfmon                           pma pmc pml pmr pmw
application/pgp-encrypted
application/pgp-keys				key
application/pgp-signature			pgp
application/pics-rules				prf
application/pkcs10                              p10
application/x-pkcs12                            p12 pfx
application/x-pkcs7-certificates  	        p7b spc
application/x-pkcs7-certreqresp                 p7r
application/pkcs7-mime                          p7c p7m
application/pkcs7-signature                     p7s
application/pkix-cert
application/pkix-crl                            crl
application/pkixcmp
application/postscript				ps ai eps
application/prs.alvestrand.titrax-sheet
application/prs.cww
application/prs.nprend
application/qsig
application/rar					rar
application/rdf+xml				rdf
application/remote-printing
application/riscos
application/rss+xml				rss
application/rtf					rtf
application/sdp
application/set-payment
application/set-payment-initiation              setpay
application/set-registration
application/set-registration-initiation         setreg
application/sgml                                sgml sml
application/sgml-open-catalog
application/sieve
application/slate
application/smil				smi smil
application/timestamp-query
application/timestamp-reply
application/vemmi
application/whoispp-query
application/whoispp-response
application/wita
application/wordperfect				wpd doc
application/wordperfect5.1			wp5
application/x400-bp
application/xhtml+xml				xhtml xht
application/xml					xml xsl
application/xml-dtd                             dtd
application/xml-external-parsed-entity
application/zip					zip
application/vnd.3M.Post-it-Notes
application/vnd.accpac.simply.aso
application/vnd.accpac.simply.imp
application/vnd.acucobol
application/vnd.aether.imp
application/vnd.anser-web-certificate-issue-initiation
application/vnd.anser-web-funds-transfer-initiation
application/vnd.audiograph
application/vnd.bmi
application/vnd.businessobjects
application/vnd.canon-cpdl
application/vnd.canon-lips
application/vnd.cinderella			cdy
application/vnd.claymore
application/vnd.commerce-battelle
application/vnd.commonspace
application/vnd.comsocaller
application/vnd.contact.cmsg
application/vnd.cosmocaller
application/vnd.ctc-posml
application/vnd.cups-postscript
application/vnd.cups-raster
application/vnd.cups-raw
application/vnd.cybank
application/vnd.dna
application/vnd.dpgraph
application/vnd.dxr
application/vnd.ecdis-update
application/vnd.ecowin.chart
application/vnd.ecowin.filerequest
application/vnd.ecowin.fileupdate
application/vnd.ecowin.series
application/vnd.ecowin.seriesrequest
application/vnd.ecowin.seriesupdate
application/vnd.enliven
application/vnd.epson.esf
application/vnd.epson.msf
application/vnd.epson.quickanime
application/vnd.epson.salt
application/vnd.epson.ssf
application/vnd.ericsson.quickcall
application/vnd.eudora.data
application/vnd.fdf
application/vnd.ffsns
application/vnd.flographit
application/vnd.framemaker
application/vnd.fsc.weblaunch
application/vnd.fujitsu.oasys
application/vnd.fujitsu.oasys2
application/vnd.fujitsu.oasys3
application/vnd.fujitsu.oasysgp
application/vnd.fujitsu.oasysprs
application/vnd.fujixerox.ddd
application/vnd.fujixerox.docuworks
application/vnd.fujixerox.docuworks.binder
application/vnd.fut-misnet
application/vnd.google-earth.kml+xml		kml
application/vnd.google-earth.kmz		kmz
application/vnd.grafeq
application/vnd.groove-account
application/vnd.groove-identity-message
application/vnd.groove-injector
application/vnd.groove-tool-message
application/vnd.groove-tool-template
application/vnd.groove-vcard
application/vnd.hhe.lesson-player
application/vnd.hp-HPGL
application/vnd.hp-PCL
application/vnd.hp-PCLXL
application/vnd.hp-hpid
application/vnd.hp-hps
application/vnd.httphone
application/vnd.hzn-3d-crossword
application/vnd.ibm.MiniPay
application/vnd.ibm.afplinedata
application/vnd.ibm.modcap
application/vnd.informix-visionary
application/vnd.intercon.formnet
application/vnd.intertrust.digibox
application/vnd.intertrust.nncp
application/vnd.intu.qbo
application/vnd.intu.qfx
application/vnd.irepository.package+xml
application/vnd.is-xpr
application/vnd.japannet-directory-service
application/vnd.japannet-jpnstore-wakeup
application/vnd.japannet-payment-wakeup
application/vnd.japannet-registration
application/vnd.japannet-registration-wakeup
application/vnd.japannet-setstore-wakeup
application/vnd.japannet-verification
application/vnd.japannet-verification-wakeup
application/vnd.koan
application/vnd.lotus-1-2-3
application/vnd.lotus-approach
application/vnd.lotus-freelance
application/vnd.lotus-notes
application/vnd.lotus-organizer
application/vnd.lotus-screencam
application/vnd.lotus-wordpro
application/vnd.mcd
application/vnd.mediastation.cdkey
application/vnd.meridian-slingshot
application/vnd.mif
application/vnd.minisoft-hp3000-save
application/vnd.mitsubishi.misty-guard.trustweb
application/vnd.mobius.daf
application/vnd.mobius.dis
application/vnd.mobius.msl
application/vnd.mobius.plc
application/vnd.mobius.txf
application/vnd.motorola.flexsuite
application/vnd.motorola.flexsuite.adsi
application/vnd.motorola.flexsuite.fis
application/vnd.motorola.flexsuite.gotap
application/vnd.motorola.flexsuite.kmr
application/vnd.motorola.flexsuite.ttc
application/vnd.motorola.flexsuite.wem
application/vnd.mozilla.xul+xml			xul
application/vnd.ms-artgalry
application/vnd.ms-asf
application/vnd.ms-excel			xls xlt xla xlb xlc xlm xlw 
application/vnd.ms-lrm
application/vnd.ms-outlook                      msg
application/vnd.ms-pki.seccat			cat
application/vnd.ms-pki.stl			stl
application/vnd.ms-powerpoint			ppt pps pot
application/vnd.ms-project                      mpp
application/vnd.ms-tnef
application/vnd.ms-works                        wcm wdb wks wps
application/winhlp                              hlp
application/vnd.mseq
application/vnd.msign
application/vnd.music-niff
application/vnd.musician
application/vnd.netfpx                          fpx
application/vnd.noblenet-directory
application/vnd.noblenet-sealer
application/vnd.noblenet-web
application/vnd.novadigm.EDM
application/vnd.novadigm.EDX
application/vnd.novadigm.EXT
application/vnd.oasis.opendocument.chart			odc
application/vnd.oasis.opendocument.database			odb
application/vnd.oasis.opendocument.formula			odf
application/vnd.oasis.opendocument.graphics			odg
application/vnd.oasis.opendocument.graphics-template		otg
application/vnd.oasis.opendocument.image			odi
application/vnd.oasis.opendocument.presentation			odp
application/vnd.oasis.opendocument.presentation-template	otp
application/vnd.oasis.opendocument.spreadsheet			ods
application/vnd.oasis.opendocument.spreadsheet-template		ots
application/vnd.oasis.opendocument.text				odt
application/vnd.oasis.opendocument.text-master			odm
application/vnd.oasis.opendocument.text-template		ott
application/vnd.oasis.opendocument.text-web			oth
application/vnd.osa.netdeploy
application/vnd.palm
application/vnd.pg.format
application/vnd.pg.osasli
application/vnd.powerbuilder6
application/vnd.powerbuilder6-s
application/vnd.powerbuilder7
application/vnd.powerbuilder7-s
application/vnd.powerbuilder75
application/vnd.powerbuilder75-s
application/vnd.previewsystems.box
application/vnd.publishare-delta-tree
application/vnd.pvi.ptid1
application/vnd.pwg-xhtml-print+xml
application/vnd.rapid
application/vnd.rim.cod				cod
application/vnd.s3sms
application/vnd.seemail
application/vnd.shana.informed.formdata
application/vnd.shana.informed.formtemplate
application/vnd.shana.informed.interchange
application/vnd.shana.informed.package
application/vnd.smaf				mmf
application/vnd.sss-cod
application/vnd.sss-dtf
application/vnd.sss-ntf
application/vnd.stardivision.calc		sdc
application/vnd.stardivision.chart		sds
application/vnd.stardivision.draw		sda
application/vnd.stardivision.impress		sdd
application/vnd.stardivision.math		sdf
application/vnd.stardivision.writer		sdw
application/vnd.stardivision.writer-global	sgl
application/vnd.street-stream
application/vnd.sun.xml.calc			sxc
application/vnd.sun.xml.calc.template		stc
application/vnd.sun.xml.draw			sxd
application/vnd.sun.xml.draw.template		std
application/vnd.sun.xml.impress			sxi
application/vnd.sun.xml.impress.template	sti
application/vnd.sun.xml.math			sxm
application/vnd.sun.xml.writer			sxw
application/vnd.sun.xml.writer.global		sxg
application/vnd.sun.xml.writer.template		stw
application/vnd.svd
application/vnd.swiftview-ics
application/vnd.symbian.install			sis
application/vnd.triscape.mxs
application/vnd.trueapp
application/vnd.truedoc
application/vnd.tve-trigger
application/vnd.ufdl
application/vnd.uplanet.alert
application/vnd.uplanet.alert-wbxml
application/vnd.uplanet.bearer-choice
application/vnd.uplanet.bearer-choice-wbxml
application/vnd.uplanet.cacheop
application/vnd.uplanet.cacheop-wbxml
application/vnd.uplanet.channel
application/vnd.uplanet.channel-wbxml
application/vnd.uplanet.list
application/vnd.uplanet.list-wbxml
application/vnd.uplanet.listcmd
application/vnd.uplanet.listcmd-wbxml
application/vnd.uplanet.signal
application/vnd.vcx
application/vnd.vectorworks
application/vnd.vidsoft.vidconference
application/vnd.visio				vsd
application/vnd.vividence.scriptfile
application/vnd.wap.sic
application/vnd.wap.slc
application/vnd.wap.wbxml			wbxml
application/vnd.wap.wmlc			wmlc
application/vnd.wap.wmlscriptc			wmlsc
application/vnd.webturbo
application/vnd.wrq-hp3000-labelled
application/vnd.wt.stf
application/vnd.xara
application/vnd.xfdl
application/vnd.yellowriver-custom-menu
application/x-123				wk
application/x-7z-compressed			7z
application/x-abiword				abw
application/x-apple-diskimage			dmg
application/x-bcpio				bcpio
application/x-bittorrent			torrent
application/x-bzip2                             bz2
application/x-cab				cab
application/x-cbr				cbr
application/x-cbz				cbz
application/x-cdf				cdf
application/x-cdlink				vcd
application/x-chess-pgn				pgn
application/x-compress                          z Z
application/x-compressed                        taz tgz tar.gz
application/x-core
application/x-cpio				cpio
application/x-csh				csh
application/x-debian-package			deb udeb
application/x-director				dcr dir dxr
application/x-dms				dms
application/x-doom				wad
application/x-dvi				dvi
application/x-httpd-eruby			rhtml
application/x-executable
application/x-flac				flac
application/x-font				pfa pfb gsf pcf pcf.Z
application/x-freemind				mm
application/x-futuresplash			spl
application/x-gnumeric				gnumeric
application/x-go-sgf				sgf
application/x-graphing-calculator		gcf
application/x-gtar				gtar tgz taz
application/x-gzip                              gz
application/x-hdf				hdf
application/x-httpd-php				phtml pht php
application/x-httpd-php-source			phps
application/x-httpd-php3			php3
application/x-httpd-php3-preprocessed		php3p
application/x-httpd-php4			php4
application/x-ica				ica
application/x-internet-signup			ins isp
application/x-iphone				iii
application/x-iso9660-image			iso
application/x-java-applet                       class
application/x-java-bean
application/x-java-commerce                     jcm
application/x-java-jnlp-file			jnlp
application/x-java-source                       java
application/x-javascript			js
application/x-jmol				jmz
application/x-kchart				chrt
application/x-kdelnk
application/x-killustrator			kil
application/x-koan				skp skd skt skm
application/x-kpresenter			kpr kpt
application/x-kspread				ksp
application/x-kword				kwd kwt
application/x-latex				latex
application/x-lha				lha
application/x-lyx				lyx
application/x-lzh				lzh
application/x-lzx				lzx
application/x-maker				frm maker frame fm fb book fbdoc
application/x-mif				mif
application/x-ms-wmd				wmd
application/x-ms-wmz				wmz
application/x-msdos-program			com exe bat dll
application/x-msi				msi
application/x-netcdf				nc cdf
application/x-ns-proxy-autoconfig		pac
application/x-nwc				nwc
application/x-object				o
application/x-oz-application			oza
application/x-pkcs7-certreqresp			p7r
application/x-pkcs7-crl				crl
application/x-python-code			pyc pyo
application/x-quicktimeplayer			qtl
application/x-redhat-package-manager		rpm
application/x-rx
application/x-sh				sh
application/x-shar				shar
application/x-shellscript
application/x-shockwave-flash			swf swfl
application/x-stuffit				sit sitx
application/x-sv4cpio				sv4cpio
application/x-sv4crc				sv4crc
application/x-tar				tar
application/x-tcl				tcl
application/x-tex-gf				gf
application/x-tex-pk				pk
application/x-texinfo				texinfo texi
application/x-trash				backup bak old sik ~ %
application/x-troff				t tr roff
application/x-troff-man				man
application/x-troff-me				me
application/x-troff-ms				ms
application/x-ustar				ustar
application/x-videolan
application/x-wais-source			src
application/x-wingz				wz
application/x-x509-ca-cert			crt
application/x-xcf				xcf
application/x-xfig				fig
application/x-xpinstall				xpi
audio/32kadpcm
audio/3gpp
audio/basic					au snd
audio/g.722.1
audio/l16
audio/midi					mid midi kar
audio/mp4a-latm
audio/mpa-robust
audio/mpeg					mpga mpega mp2 mp3 m4a
audio/mpegurl					m3u
audio/ogg					oga spx
audio/parityfec
audio/prs.sid					sid
audio/telephone-event
audio/tone
audio/vnd.cisco.nse
audio/vnd.cns.anp1
audio/vnd.cns.inf1
audio/vnd.digital-winds
audio/vnd.everad.plj
audio/vnd.lucent.voice
audio/vnd.nortel.vbk
audio/vnd.nuera.ecelp4800
audio/vnd.nuera.ecelp7470
audio/vnd.nuera.ecelp9600
audio/vnd.octel.sbc
audio/vnd.qcelp
audio/vnd.rhetorex.32kadpcm
audio/vnd.vmx.cvsd
audio/x-aiff					aif aiff aifc
audio/x-gsm					gsm
audio/x-mpegurl					m3u
audio/x-ms-wma					wma
audio/x-ms-wax					wax
audio/x-pn-realaudio-plugin
audio/x-pn-realaudio				ra rm ram
audio/x-realaudio				ra
audio/x-scpls					pls
audio/x-sd2					sd2
audio/x-wav					wav
chemical/x-alchemy				alc
chemical/x-cache				cac cache
chemical/x-cache-csf				csf
chemical/x-cactvs-binary			cbin cascii ctab
chemical/x-cdx					cdx
chemical/x-cerius				cer
chemical/x-chem3d				c3d
chemical/x-chemdraw				chm
chemical/x-cif					cif
chemical/x-cmdf					cmdf
chemical/x-cml					cml
chemical/x-compass				cpa
chemical/x-crossfire				bsd
chemical/x-csml					csml csm
chemical/x-ctx					ctx
chemical/x-cxf					cxf cef
chemical/x-daylight-smiles			smi
chemical/x-embl-dl-nucleotide			emb embl
chemical/x-galactic-spc				spc
chemical/x-gamess-input				inp gam gamin
chemical/x-gaussian-checkpoint			fch fchk
chemical/x-gaussian-cube			cub
chemical/x-gaussian-input			gau gjc gjf
chemical/x-gaussian-log				gal
chemical/x-gcg8-sequence			gcg
chemical/x-genbank				gen
chemical/x-hin					hin
chemical/x-isostar				istr ist
chemical/x-jcamp-dx				jdx dx
chemical/x-kinemage				kin
chemical/x-macmolecule				mcm
chemical/x-macromodel-input			mmd mmod
chemical/x-mdl-molfile				mol
chemical/x-mdl-rdfile				rd
chemical/x-mdl-rxnfile				rxn
chemical/x-mdl-sdfile				sd sdf
chemical/x-mdl-tgf				tgf
chemical/x-mif					mif
chemical/x-mmcif				mcif
chemical/x-mol2					mol2
chemical/x-molconn-Z				b
chemical/x-mopac-graph				gpt
chemical/x-mopac-input				mop mopcrt mpc dat zmt
chemical/x-mopac-out				moo
chemical/x-mopac-vib				mvb
chemical/x-ncbi-asn1				asn
chemical/x-ncbi-asn1-ascii			prt ent
chemical/x-ncbi-asn1-binary			val aso
chemical/x-ncbi-asn1-spec			asn
chemical/x-pdb					pdb ent
chemical/x-rosdal				ros
chemical/x-swissprot				sw
chemical/x-vamas-iso14976			vms
chemical/x-vmd					vmd
chemical/x-xtel					xtel
chemical/x-xyz					xyz
image/cgm
image/g3fax                                     g3
image/gif					gif
image/ief					ief
image/jpeg					jpeg jpg jpe jfif
image/pipeg					jpeg jpg jpe jfif 
image/pjpeg					jpeg jpg jpe jfif 
image/naplps
image/pcx					pcx
image/png					png
image/prs.btif
image/prs.pti
image/svg+xml					svg svgz
image/tiff					tiff tif
image/vnd.cns.inf2
image/vnd.djvu					djvu djv
image/vnd.dwg                                   dwg
image/vnd.dxf                                   dxf
image/vnd.fastbidsheet
image/vnd.fpx                                   fpx
image/vnd.fst
image/vnd.fujixerox.edmics-mmr
image/vnd.fujixerox.edmics-rlc
image/vnd.mix
image/vnd.net-fpx                               fpx
image/vnd.svf
image/vnd.wap.wbmp				wbmp
image/vnd.xiff
image/x-cmu-raster				ras
image/x-coreldraw				cdr
image/x-coreldrawpattern			pat
image/x-coreldrawtemplate			cdt
image/x-corelphotopaint				cpt
image/x-icon					ico
image/x-jg					art
image/x-jng					jng
image/x-ms-bmp					bmp
image/x-photoshop				psd
image/x-portable-anymap				pnm
image/x-portable-bitmap				pbm
image/x-portable-graymap			pgm
image/x-portable-pixmap				ppm
image/x-rgb					rgb
image/x-xbitmap					xbm
image/x-xpixmap					xpm
image/x-xwindowdump				xwd
inode/chardevice
inode/blockdevice
inode/directory-locked
inode/directory
inode/fifo
inode/socket
message/delivery-status
message/disposition-notification
message/external-body
message/http
message/s-http
message/news
message/partial
message/rfc822					eml
model/iges					igs iges
model/mesh					msh mesh silo
model/vnd.dwf                                   dwf
model/vnd.flatland.3dml
model/vnd.gdl
model/vnd.gs-gdl
model/vnd.gtw
model/vnd.mts
model/vnd.vtu
model/vrml					wrl vrml
multipart/alternative
multipart/appledouble
multipart/byteranges
multipart/digest
multipart/encrypted
multipart/form-data
multipart/header-set
multipart/mixed
multipart/parallel
multipart/related
multipart/report
multipart/signed
multipart/voice-message
text/calendar					ics icz
text/css					css
text/csv					csv
text/directory
text/english
text/enriched
text/h323					323
text/html					html htm shtml sht
text/iuls					uls
text/mathml					mml
text/parityfec
text/plain					asc txt text pot
text/prs.lines.tag
text/rfc822-headers
text/richtext					rtx
text/rtf                                        rtf
text/scriptlet					sct wsc
text/t140
text/texmacs					tm ts
text/tab-separated-values			tsv
text/uri-list
text/vnd.abc
text/vnd.curl
text/vnd.DMClientScript
text/vnd.flatland.3dml
text/vnd.fly
text/vnd.fmi.flexstor
text/vnd.in3d.3dml
text/vnd.in3d.spot
text/vnd.IPTC.NewsML
text/vnd.IPTC.NITF
text/vnd.latex-z
text/vnd.motorola.reflex
text/vnd.ms-mediapackage
text/vnd.sun.j2me.app-descriptor		jad
text/vnd.wap.si
text/vnd.wap.sl
text/vnd.wap.wml				wml
text/vnd.wap.wmlscript				wmls
text/x-bibtex					bib
text/x-boo					boo
text/x-c++hdr					h++ hpp hxx hh
text/x-c++src					c++ cpp cxx cc
text/x-chdr					h
text/x-component				htc
text/x-crontab
text/x-csh					csh
text/x-csrc					c
text/x-dsrc					d
text/x-diff					diff patch
text/x-fortran                                  f f77 f90 for
text/x-haskell					hs
text/x-java					java
text/x-literate-haskell				lhs
text/x-makefile
text/x-moc					moc
text/x-pascal					p pas
text/x-pcs-gcd					gcd
text/x-perl					pl pm
text/x-prolog                                   pl pro prolog
text/x-python					py
text/x-server-parsed-html
text/x-setext					etx
text/x-sh					sh
text/x-tcl					tcl tk
text/x-tex					tex ltx sty cls
text/x-turtle
text/x-vcalendar				vcs
text/x-vcard					vcf
video/3gpp					3gp
video/dl					dl
video/dv					dif dv
video/fli					fli
video/gl					gl
video/mpeg					mpeg mpg mpe
video/mp4					mp4
video/ogg					ogv
video/quicktime					qt mov
video/mp4v-es
video/parityfec
video/pointer
video/vnd.fvt
video/vnd.motorola.video
video/vnd.motorola.videop
video/vnd.mpegurl				mxu
video/vnd.mts
video/vnd.nokia.interleaved-multimedia
video/vnd.vivo
video/x-la-asf					lsf lsx
video/x-mng					mng
video/x-ms-asf					asf asx
video/x-ms-wm					wm
video/x-ms-wmv					wmv
video/x-ms-wmx					wmx
video/x-ms-wvx					wvx
video/x-msvideo					avi
video/x-sgi-movie				movie
x-conference/x-cooltalk				ice
x-epoc/x-sisx-app				sisx
x-world/x-vrml					vrm vrml wrl
