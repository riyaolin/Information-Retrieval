#!/usr/bin/perl
use LWP::Simple;

open(DOCLIST,"<doclist.txt") or die "Failed to open: $!\n\n";
while(<DOCLIST>){
       @line = split(/\s+/,$_);
       $id_map{$line[0]}=$line[1];
}
close(DOCLIST);

open(FILE,">result.txt") or die "Failed to open: $!\n\n";
$base = "http://fiji4.ccs.neu.edu/~zerg/lemurcgi/lemur.cgi?g=p&d=0&v=";
@query_num = ("85","59","56","71","64","62","93","99","58","77","54","87",
              "94","100","89","61","95","68","57","97","98","60","80","63","91");
#@query_num =("85","59");
$query_i = 0;
while($query_i < 25){
         $filename = $query_num[$query_i].".txt";
         open(FH,$filename) or die "Failed to open: $!\n\n";
         while(<FH>){
                $line = $_;
                chomp($line);
                print "Processing... $line\n";
                $url = $base.$line;
                $content = get($url);
                while($content=~ m/([0-9]+)/g){
                       $word = $1;
                        push (@temp, $word);
                        }
                $doc_num = $temp[3];
                $index_i = 4;
                while($index_i < $doc_num*3+3){
                       $docid = $temp[$index_i];
                       $freq = $temp[$index_i+2];
                       if(exists $score_hash{$temp[$index_i]}){
                          $score_hash{$docid} += $freq;
                       }
                       else{
                            $score_hash{$docid} = $freq;
                            }
                       $index_i+=3;
                }
                splice (@temp,0);  #re-use the array, made a mistake here
         }

          #sorting a Hash by score by value in decending Order
          sub desc_score_sort {
              $score_hash{$b} <=> $score_hash{$a};
          }

          #output the result, including the rank
          $rank_num = 1;
          foreach $key (sort desc_score_sort(keys(%score_hash))){
                   if ($rank_num < 1001){
                     $score = $score_hash{$key};
                     printf FILE "%d Q0 %s %d %f Exp\n",
                            $query_num[$query_i],$id_map{$key},$rank_num,$score;
                     $rank_num++;
                   }
          }
          #delete the all the value in hash, in order to re-use
          foreach $key1 (keys(%score_hash)){
                   delete $score_hash{$key1};
                  }
        #tracking the process
        printf "Complete Query %s\n",$query_num[$query_i];
        $query_i++;
}
close(FH);
close(FILE);