#!/usr/bin/perl
use LWP::Simple;

open(DOCLIST,"<doclist.txt") or die "Failed to open: $!\n\n";
while(<DOCLIST>){
       @line = split(/\s+/,$_);
       $id_map{$line[0]}=$line[1];
}

open(FILE,">result.txt") or die "Failed to open: $!\n\n";
$base = "http://fiji4.ccs.neu.edu/~zerg/lemurcgi/lemur.cgi?g=p&d=3&v=";
$avg_doclen = 288;  #the average document length of database3
$num_doc = 84678;   #the number of total documents in database3
@query_num = ("85","59","56","71","64","62","93","99","58","77","54","87",
              "94","100","89","61","95","68","57","97","98","60","80","63","91");
#@query_num = ("100");
$query_i = 0;
while($query_i < 25){
         $filename = $query_num[$query_i].".txt";
         open(FH,"cleanup_queries/".$filename) or die "Failed to open: $!\n\n";

         #get all the frequency of terms in the query
         while(<FH>){
                $line = $_;
                chomp($line);
                if(exists $qf{$line}){
                   $qf{$line} += 1;
                }
                else{
                     $qf{$line} = 1;
                }
         }
         close (FH);

         open(FH,"cleanup_queries/".$filename) or die "Failed to open: $!\n\n";
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
                       $doclen = $temp[$index_i+1];
                       $bign =  1.2*(0.25+.075*$doclen/$avg_doclen);
                       $bm25 = log(1/(($doc_num+0.5)/($num_doc-$doc_num+0.5))*(1.2+1)*$freq/($bign+$freq)*(100+1)*$qf{$line}/(100+$qf{$line}));
                       if(exists $score_hash{$temp[$index_i]}){
                          $score_hash{$docid} += $bm25;
                       }
                       else{
                            $score_hash{$docid} = $bm25;
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

        #re-use the %qf hash
        foreach $key (keys (%qf)){
                 delete $qf{$key};
        }

        $query_i++;
}
close(FH);
close(FILE);