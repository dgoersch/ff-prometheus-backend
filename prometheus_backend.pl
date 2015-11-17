#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Config::IniFiles;
use JSON;

# read configfile
my $configfile       = exists $ARGV[0] ? $ARGV[0] : dirname($0)."/prometheus_backend.ini";
my $cfg              = Config::IniFiles->new(-file => $configfile ) or &print_usage;
my $onoffnodesfile   = $cfg->val('general', 'onoffnodesfile');
my $modelsnodesfile  = $cfg->val('general', 'modelsnodesfile');
my $clientsnodesfile = $cfg->val('general', 'clientsnodesfile');
my $trafficnodesfile = $cfg->val('general', 'trafficnodesfile');
my $loadnodesfile    = $cfg->val('general', 'loadnodesfile');
my $memorynodesfile  = $cfg->val('general', 'memorynodesfile');

# open target prom-files for writing
open(my $onoffnodes,   '>:encoding(UTF-8)', "$onoffnodesfile")   or die "Could not open target file '$onoffnodesfile': $!";
open(my $modelsnodes,  '>:encoding(UTF-8)', "$modelsnodesfile")  or die "Could not open target file '$modelsnodesfile': $!";
open(my $clientsnodes, '>:encoding(UTF-8)', "$clientsnodesfile") or die "Could not open target file '$clientsnodesfile': $!";
open(my $trafficnodes, '>:encoding(UTF-8)', "$trafficnodesfile") or die "Could not open target file '$trafficnodesfile': $!";
open(my $loadnodes,    '>:encoding(UTF-8)', "$loadnodesfile")    or die "Could not open target file '$loadnodesfile': $!";
open(my $memorynodes,  '>:encoding(UTF-8)', "$memorynodesfile")  or die "Could not open target file '$memorynodesfile': $!";

# running through communities
for my $community (@{$cfg->{mysects}}) {

    # skip general section
    if($community eq 'general') { next; }

    # read community settings
    my $sourcefile    = $cfg->val($community, 'sourcefile');

    # open and read sourcefile
    open(my $nsfh, '<:encoding(UTF-8)', "$sourcefile") or die "Could not open target file '$sourcefile': $!";
    my $nodes_source_text = join("", <$nsfh>);

    # create json object from source data
    my $json = decode_json($nodes_source_text);

    my $nodes_online  = 0;
    my $nodes_offline = 0;
    my $clients       = 0;
    my %models;

    # running through nodes
    for my $node (keys(%{$json->{nodes}})) {

        # count online and offline nodes
        if( $json->{nodes}->{$node}->{flags}->{online} ) {
            $nodes_online++;
        } else {
            $nodes_offline++;
        }

        # count clients
        $clients = $clients + $json->{nodes}->{$node}->{statistics}->{clients};

        # get model name
        my $model = $json->{nodes}->{$node}->{nodeinfo}->{hardware}->{model};

        # convert special chars in model name to underscore and strip multiple underscores to single underscore
        $model = lc($model);
        $model =~ tr/a-z0-9/_/c;
        $model =~ s/_+/_/g;

        # count models
        $models{$model}++;

        # write clients each node if in json
        if( $json->{nodes}->{$node}->{statistics}->{clients} ) {
            print $clientsnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_clients ".$json->{nodes}->{$node}->{statistics}->{clients}."\n";
        } else {
            print $clientsnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_clients 0\n";
        }

        # write traffic each node (rx + tx + forward)
        if( $json->{nodes}->{$node}->{statistics}->{traffic}->{rx}->{bytes} && $json->{nodes}->{$node}->{statistics}->{traffic}->{tx}->{bytes} && $json->{nodes}->{$node}->{statistics}->{traffic}->{forward}->{bytes} ) {
            print $trafficnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_traffic ".( $json->{nodes}->{$node}->{statistics}->{traffic}->{rx}->{bytes} + $json->{nodes}->{$node}->{statistics}->{traffic}->{tx}->{bytes} + $json->{nodes}->{$node}->{statistics}->{traffic}->{forward}->{bytes} )."\n";
        } else {
            print $trafficnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_traffic 0\n";
        }

        # write load each node if in json
        if ( $json->{nodes}->{$node}->{statistics}->{loadavg} ) {
            print $loadnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_load ".$json->{nodes}->{$node}->{statistics}->{loadavg}."\n";
        } else {
            print $loadnodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_load 0\n";
        }

        # write memory each node if in json
        if ( $json->{nodes}->{$node}->{statistics}->{memory_usage} ) {
            print $memorynodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_memory ".$json->{nodes}->{$node}->{statistics}->{memory_usage}."\n";
        } else {
            print $memorynodes "ffnode_".$json->{nodes}->{$node}->{nodeinfo}->{node_id}."_memory 0\n";
        }
    }

    # write nodes stats
    print $onoffnodes $community."_nodes_online ".$nodes_online."\n";
    print $onoffnodes $community."_nodes_offline ".$nodes_offline."\n";
    print $onoffnodes $community."_clients ".$clients."\n";

    # write used hardware models
    print $modelsnodes map { $community."_model_".$_." ".$models{$_}."\n" } keys %models;

    # close source file
    close($nsfh);
}

# close target files
close($onoffnodes);
close($modelsnodes);
close($clientsnodes);
close($trafficnodes);
close($loadnodes);
close($memorynodes);

# print usage
sub print_usage {
    print "USAGE:\n";
    print "$0 [configfile]\n";
    print "  configfile     full path to the config file, default is prometheus_backend.ini in programm directory\n\n";
    exit(1);
}
