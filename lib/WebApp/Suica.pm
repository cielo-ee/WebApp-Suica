package WebApp::Suica;

use 5.006;
use strict;
use warnings;

use File::Basename;

use Encode;
use utf8;
use DBI;
use Text::CSV_XS;

use Time::Piece;

our $VERSION='0.00001';

sub new{
    my ($class,%params) = @_;
    my $filename = basename($params{'filename'});
    $filename =~ /^(.+?)_/;
    my $identifier = $1;
    print $identifier;
    my $dbname = "$identifier.db";
    my $dbh    = DBI->connect("dbi:SQLite:dbname=$dbname");
    
    bless +{
        dbh      => $dbh,
        filepath => $params{'filename'},
        fields   => undef
    },$class;
}


sub init_db{
    my $self = shift;
    my $dbh  = $self->{'dbh'};
    
    my @main_fields = qw/id date agency s_station s_comp s_line e_station e_comp e_line fare balance /; #CSVに含まれているフィールド
    my @option_fields = qw/filename registration_date update_state update_date/; #付加するフィールド
    my @fields = (@main_fields,@option_fields);
    my $fieldlist = join ',',@fields;
    $self->{'fields'} = \@fields;
    
    $dbh->do("create table if not exists suica ($fieldlist,primary key(id,date))");
    
}


sub register_csv2db{
    my ($self,%params) = @_;
    my $csvname = $self->{'filepath'};
    my $dbh = $self->{'dbh'};
    $self->init_db;

    my @fields = @{$self->{'fields'}};


    my $t = localtime(time);

    my $timezone = sprintf "+%02d:%02d",$t->tzoffset / 3600 ,($t->tzoffset % 3600) / 60;
    my $date = $t->datetime.$timezone; #ISO 8601 style
    
    open my $fh,'<',$csvname or die "$!";
    my $csv = Text::CSV_XS-> new({binary => 1});

    while(my $columns = $csv->getline($fh)){
        #ハッシュにマッピング
        my $eles;
        @$eles{@fields} = @$columns;
        $eles->{'filename'} = $csvname;
        $eles->{'registration_date'}     = $date;

        #タイトル行を飛ばす
        next if($eles->{'id'} eq "ID");

        #各フィールドを読んで整形する
        my $valuelist = $eles->{'id'};
        foreach my $i(1..$#fields){
            my $value = decode('UTF-8',$eles->{$fields[$i]});
            $value =~ s/￥|,//g if($fields[$i] eq 'fare');
            $value =~ s/￥|,//g if($fields[$i] eq 'balance');
            $valuelist .= ",\'".$value."\'";
        }

        #重複データを検査する
        my $stmt = "select * from suica where id = $columns->[0]";
        my $sth  = $dbh -> prepare($stmt);
        $sth -> execute;
        next if($sth->fetchrow_array);

        my $fieldlist = join ',',@fields;
        $dbh->do("insert into suica ($fieldlist) values ($valuelist)");
    }

    $csv->eof;
}



sub show_all_db{
    my $self = shift;
    my $dbh  = $self->{'dbh'};
    my $stmt = "select * from suica order by id asc";
    
    my $sth  = $dbh->prepare($stmt);
    $sth -> execute;
    
    while(my @row = $sth->fetchrow_array){
        print join '|',@row;
        print "\n";
    }
}
__END__



