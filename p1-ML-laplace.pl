#!/usr/bin/perl
use LWP::Simple;

# map the internal ID and external ID of each document
open(DOCLIST,"<doclist.txt") or die "Failed to open: $!\n\n";
while(<DOCLIST>){
       @line = split(/\s+/,$_);
       $id_map{$line[0]}=$line[1];
}

#store the ranked list in result.txt
open(FILE,">result.txt") or die "Failed to open: $!\n\n";
$base = "http://fiji4.ccs.neu.edu/~zerg/lemurcgi/lemur.cgi?g=p&d=3&v=";
$num_unique_terms = 166054;  #the unique terms in database3
# @query_num = ("85","59","56","71","64","62","93","99","58","77","54","87",
 #              "94","100","89","61","95","68","57","97","98","60","80","63","91");
@query_num = ("61");
$query_i = 0;
while($query_i < 1){
       $filename = $query_num[$query_i].".txt";
       open(FH,"queries/".$filename) or die "Failed to open: $!\n\n";
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

              #build up the maximum likelihood with LAPLACE SMOOTHING matrix
              #for all the documents thats contain any words in the query
              #use hash of hashes
              $doc_num = $temp[3];
              $total_f = $temp[2];
              if ($total_f >0){
                $index_i = 4;
                while ($index_i < $doc_num*3+3){
                        $freq = $temp[$index_i+2];
                        $docid = $temp[$index_i];
                        $doclen = $temp[$index_i+1];
                        $laplace = log(($freq+1)/($doclen+$num_unique_terms));
                        if(exists $score_hash->{$docid}->{$line}){
                           $score_hash->{$docid}->{$line} +=$laplace;
                        }
                        else{
                             $score_hash->{$docid}->{$line} =$laplace;
                        }
                        $index_i += 3;

                }   # the end of while ($index_i < $doc_num*3+3) condition

                #collect missing_words' probabilitis of all the documents
                $missing_p = log(1/($doclen+$num_unique_terms));
                $back_p{$line} = $missing_p;
              } #the end of if $total_f > 0 condition

              splice (@temp,0);   #re-use the array @temp
       }

       #make up the missing_words probabilities for all the document
       foreach $key (keys (%back_p)){
                foreach $kk (keys %{$score_hash}){
                         if(!exists $score_hash->{$kk}->{$key}){
                            $score_hash->{$kk}->{$key} = $back_p{$key};
                         }
                }
       }

       #re-use the %back_p hash
       foreach $key (keys (%back_p)){
                delete $back_p{$key};
       }

       #compute the final scores for the documents and put them into
       #a new hash, called final_score
       $product = 0;
       foreach $key (keys %{$score_hash}){
                while(($nkey, $nvalue)= each(%{$score_hash->{$key}})){
                        #  print "KKK $nkey VVV $nvalue\n";
                        $product +=$nvalue;
                       # delete $score_hash->{$key}->{$nkey};
                        #  print "Ppp $product\n";
                }
                $final_score{$key} = $product;
                # printf "$key,$final_score{$key}\n";
                $product = 0; #reset the value of $product
       }

       #re-use a hash of hashes
       foreach $key (keys %{$score_hash}){
                foreach $kkey (keys %{$score_hash->{$key}}){
                         delete $score_hash->{$key}->{$kkey};
                }
       }

       #sorting a Hash by score by value in decending Order
       sub desc_score_sort {
           $final_score{$b} <=> $final_score{$a};
       }

       #output the result, including the rank
       $rank_num = 1;
       foreach $key (sort desc_score_sort(keys(%final_score))){
                if ($rank_num < 1001){
                $score = $final_score{$key};
                printf FILE "%d Q0 %s %d %f Exp\n",
                $query_num[$query_i],$id_map{$key},$rank_num,$score;
                $rank_num++;
                }
       }
       #delete the all the value in hash, in order to re-use
       foreach $key1 (keys(%score_hash)){
                delete $final_score{$key1};
       }
       #tracking the process
       printf "Complete Query %s\n",$query_num[$query_i];
       $query_i++;
}
close(FH);
close(FILE);