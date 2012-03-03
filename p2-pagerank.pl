#!/usr/bin/perl

#Questions:
#if there are only a few pages in the web and only a few pages have incoming or
#outgoing pages, which means that most of the pages are seperated
#then, the pagerank fomula will give a large score for those no outgoing pages??

#wrapping the data into three hashes
#first hash: %pages, which contains all the page ID in the subweb
#second hash: %L, which represents the number of outgoing links from each page
#third hash: %M, represents a list of pages that link to each page
open(FILE, "inlinks.txt")or die "Failed to open: $!\n\n";
while(<FILE>){
       $line = $_;
       @arr = split(/\s/g,$line);
       $arr_size = $#arr+1;
       $in_page = $arr[0];
       #dummy hash, to record the pages in the web
       $pages{$in_page} = 0;
       for (my $i = 1; $i < $arr_size; $i++){
            if(!exists $pages{$arr[$i]}){
               $pages{$arr[$i]} = 0;
            }
            if(exists $L{$arr[$i]}){
               $L{$arr[$i]} += 1;
            }else{
               $L{$arr[$i]} = 1;
             }
             push (@{ $M{$in_page} }, $arr[$i]);
       }
}
#collect the sink set
foreach $key (keys %pages){
         if (!exists $L{$key}){
             push (@sinks, $key);
         }
}
@p = keys %pages;
$page_num = $#p + 1;
close (FILE);

print "Finish wrapping the data...\n";

#define the damping factor teleportation constant
$d = 0.85;

#give the initial pagerank value for each node
foreach $key (keys %pages){
         $PR{$key} = 1.0/$page_num;
         $newPR{$key} = 0.0;
         #print "$PR{$key}\n";
}

$stop_counter = 0;
$perplexity = 0;
$loop_counter = 1;
open(FILE, ">perplexity.txt")or die "Failed to open: $!\n\n";
while ($stop_counter < 4){
        #collect the pagerank contained in sink set
        $sinkPR = 0;
        foreach (@sinks){
                  $sinkPR += $PR{$_};
        }
        foreach $page_in (keys (%PR)){
                 $newPR{$page_in} = (1-$d)/$page_num;
                 $newPR{$page_in} += $d*$sinkPR/$page_num; #make up the sink PR
                 foreach $page_out (@{ $M{$page_in} }){
                          $newPR{$page_in} += $d*$PR{$page_out}/$L{$page_out};
                 }
        }
        #The entropy and perplexity
        $entropy = 0.0;
        foreach $element (%PR){
                 if ($element >0){
                      $entropy += $element*(log(1.0/$element)/log(2));
                 }
        }
        $old_perplexity = $perplexity;
        $perplexity = 2**$entropy;
        print "Entropy: $entropy Perplexity: $perplexity\n";
        print FILE "Iteration $loop_counter, Perplexity:    $perplexity\n";
        if(abs($old_perplexity - $perplexity)< 1){
           $stop_counter ++;
        }
        else{
             $stop_counter = 0;
        }

        foreach $page (keys (%newPR)){
                 $PR{$page} = $newPR{$page};
        }
        $loop_counter++;
}
close(FILE);

#sorting a Hash by score by value in decending Order
sub desc_score_sort {
    $PR{$b} <=> $PR{$a};
}
open(FILE, ">pagerak_result.txt")or die "Failed to open: $!\n\n";
#output the result, including the rank
$rank_num = 1;
foreach $key (sort desc_score_sort(keys(%PR))){
        $score = $PR{$key};
        printf FILE "%-15s %d %-15f\n",$key,$rank_num,$score;
        $rank_num++;
}
close(FILE);