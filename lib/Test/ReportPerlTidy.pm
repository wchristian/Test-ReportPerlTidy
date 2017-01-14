package Test::ReportPerlTidy;

use strictures 2;

# VERSION

# ABSTRACT:

# COPYRIGHT

use Test::More 0.88;
use IO::All -binary;
use Capture::Tiny 'capture_merged';
use Perl::Tidy 'perltidy';
use Try::Tiny;

SKIP: if ( !eval { require Capture::Tiny && require Perl::Tidy } ) {
    skip "test requires Capture::Tiny and Perl::Tidy", 1;
    exit;
}

SKIP: if ( $ENV{SKIP_TIDY_TESTS} ) {
    skip "test skipped due to \$ENV{SKIP_TIDY_TESTS}", 1;
    exit;
}

sub run {
    my ( $exclude_filter ) = @_;
    note "set \$ENV{SKIP_TIDY_TESTS} to skip these";
    try { report_untidied_files( $exclude_filter ) } catch { diag $_ };
    pass;
}

sub report_untidied_files {
    my ( $exclude_filter ) = @_;

    my @files  = io( "." )->All_Files;
    my $untidy = 0;
    for my $file ( @files ) {
        my ( $status, $diff ) = process_file( $file, $exclude_filter );
        next if $status->{skipped};
        note sprintf " %s%s | $file%s",    #
          $status->{perl}     ? "p"       : " ",    #
          $status->{excluded} ? "e"       : " ",    #
          $diff               ? "\n$diff" : "";
        $untidy++ if $diff;
    }

    diag "found $untidy untidy files, test in verbose mode for details"
      if $untidy and !$ENV{TEST_VERBOSE};

    return;
}

sub process_file {
    my ( $file, $exclude_filter ) = @_;

    my %status;
    $status{skipped} = $file =~ /(\bblib\b|^\.git)/;
    return \%status if $status{skipped};

    $status{perl} = $file =~ /(^[^.]|\.(pl|PL|pm|t))$/;
    $status{excluded} = ( $exclude_filter and $exclude_filter->( $file ) );
    return \%status if $status{excluded} or !$status{perl};

    my $source = $file->all;
    my $tidy   = transform_source( $source );
    return \%status if $source eq $tidy;

    return ( \%status, " !!! not tidy" ) if !require Text::Diff;

    my $diff = Text::Diff::diff( \$source, \$tidy, { STYLE => 'Unified', CONTEXT => 0 } );
    my @diff = split /\n/, $diff;
    @diff = ( @diff[ 0 .. 19 ], "[... snip ...]" ) if @diff > 20;
    $diff = join "\n", ( "-" x 78 ), @diff, ( "-" x 78 );
    return ( \%status, $diff );
}

# from Code::TidyAll::Plugin::PerlTidy
sub transform_source {
    my ( $source ) = @_;

    # perltidy reports errors in two different ways.
    # Argument/profile errors are output and an error_flag is returned.
    # Syntax errors are sent to errorfile or stderr, depending on the
    # the setting of -se/-nse (aka --standard-error-output).  These flags
    # might be hidden in other bundles, e.g. -pbp.  Be defensive and
    # check both.
    my ( $errorfile, $stderr, $destination );
    my ( $output, $error_flag ) = capture_merged {
        perltidy
          source      => \$source,
          destination => \$destination,
          stderr      => \$stderr,
          errorfile   => \$errorfile;
    };
    die $stderr          if $stderr;
    die $errorfile       if $errorfile;
    die $output          if $error_flag;
    print STDERR $output if defined $output;
    return $destination;
}

1;
