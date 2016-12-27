use Modern::Perl;
use File::Basename;

my @files = @ARGV;
my $iterations = 5;
my $report;
my ( @steps, @versions );
say "RAW DATA";
for my $file ( @files ) {
    open my $fh, '<', $file;
    my $version = basename $file;
    $version =~ s/\.txt//;
    push @versions, $version;
    while ( my $line = <$fh> ) {
        chomp $line;
        next unless $line =~ m|^CP |;
        my ( $step, $time ) = split ' = ', $line;
        push @steps, $step unless grep {/^$step$/} @steps;
        push @{ $report->{$version}{$step} }, $time;
    }
    close $fh;
}

my $total;
for my $version ( @versions ) {
    say $version;
    for my $step ( @steps ) {
        my @times = @{ $report->{$version}{$step} };
        if ( scalar @times != $iterations ) {
            die "$version:$step is wrong";
        }
        my $sum;
        $sum += $_ for @times;
        my $avg = $sum / $iterations;
        say $step . '|' . join ( '+', @times ) . ' => ' . $avg;
        $total->{$version}{$step} = $avg;
    }
}

say "\nAverage";
say "steps;" . join ";", @versions;
for my $step ( @steps ) {
    print $step;
    for my $version ( @versions ) {
        print ';'.$total->{$version}{$step}
    }
    print "\n";
}
