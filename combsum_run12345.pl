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
#open(T, ">>track.txt") or die "Failed to open: $!\n\n";

# basic information prepare
$base = "http://fiji4.ccs.neu.edu/~zerg/lemurcgi/lemur.cgi?g=p&d=3&v=";
$num_unique_terms = 166054;  #the unique terms in database3
$num_terms = 24401877; #the total term in database3
$avg_doclen = 288;  #the average document length of database3
$num_doc = 84678;   #the number of total documents in database3
@query_num = ("85","59","56","71","64","62","93","99","58","77","54","87",
               "94","100","89","61","95","68","57","97","98","60","80","63","91");
#@query_num = ("85","59");
$query_i = 0;

# ------ Queries Processing ----------------------
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
       # Process queries word by word
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

              # ------------------- Models Processing ---------------------
              # -----------------------------------------------------------

              # --- Okapi tf-idf ---Run1 -----
              $doc_num = $temp[3];
              $total_f = $temp[2];
              if ($total_f >0){
                   $index_i = 4;
                   while($index_i < $doc_num*3+3){
                          $docid = $temp[$index_i];
                          $freq = $temp[$index_i+2];
                          $tf_idf = ($freq/($freq+0.5+(1.5*$temp[$index_i+1]/$avg_doclen)))*log($num_doc/$doc_num);
                          if(exists $tf_idf_score_hash{$temp[$index_i]}){
                             $tf_idf_score_hash{$docid} += $tf_idf;
                          }
                          else{
                               $tf_idf_score_hash{$docid} = $tf_idf;
                          }
                          $index_i+=3;
                   }
              }

              # --- Okapi tf ----Run2 -------
              $doc_num = $temp[3];
              $total_f = $temp[2];
              if ($total_f >0){
                   $index_i = 4;
                   while($index_i < $doc_num*3+3){
                          $docid = $temp[$index_i];
                          $freq = $temp[$index_i+2];
                          $oktf = $freq/($freq+0.5+(1.5*$temp[$index_i+1]/288));
                          if(exists $oktf_score_hash{$temp[$index_i]}){
                             $oktf_score_hash{$docid} += $oktf;
                          }
                          else{
                               $oktf_score_hash{$docid} = $oktf;
                          }
                          $index_i+=3;
                   }
              }

              # --- JELINEK-MERCER --- Run4---
              #build up the maximum likelihood with JELINEK-MERCER SMOOTHING matrix
              #for all the documents thats contain any words in the query
              #use hash of hashes
              $doc_num = $temp[3];
              $total_f = $temp[2];
              if ($total_f >0){
                   $index_i = 4;
                   while ($index_i < $doc_num*3+3){
                           $freq = $temp[$index_i+2];
                           $docid = $temp[$index_i];
                           $jk = log(0.2*$freq/$temp[$index_i+1]+0.8*$total_f/$num_terms);
                           if(exists $jm_score_hash->{$docid}->{$line}){
                              $jm_score_hash->{$docid}->{$line} +=$jk;
                           }
                           else{
                                $jm_score_hash->{$docid}->{$line} =$jk;
                           }
                           $index_i += 3;

                   }   # the end of while ($index_i < $doc_num*3+3) condition

                   #collect the background probabilities of all the terms in the corpus
                   $background_p = log((0.8*($total_f/$num_terms)));
                   $jm_back_p{$line} = $background_p;
              } #the end of if $total_f > 0 condition

              # --- BM25 ----Run3 -------
              $doc_num = $temp[3];
              $total_f = $temp[2];
              if ($total_f >0){
                   $index_i = 4;
                   while($index_i < $doc_num*3+3){
                       $docid = $temp[$index_i];
                       $freq = $temp[$index_i+2];
                       $doclen = $temp[$index_i+1];
                       $bign =  1.2*(0.25+.075*$doclen/$avg_doclen);
                       $bm25 = log(1/(($doc_num+0.5)/($num_doc-$doc_num+0.5))*(1.2+1)*$freq/($bign+$freq)*(100+1)*$qf{$line}/(100+$qf{$line}));
                       if(exists $bm_score_hash{$temp[$index_i]}){
                          $bm_score_hash{$docid} += $bm25;
                       }
                       else{
                            $bm_score_hash{$docid} = $bm25;
                            }
                       $index_i+=3;
                   }
              }

              # --- LAPLACE SMOOTHING -----Run5 -------
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
                           if(exists $laplace_score_hash->{$docid}->{$line}){
                              $laplace_score_hash->{$docid}->{$line} +=$laplace;
                           }
                           else{
                                $laplace_score_hash->{$docid}->{$line} =$laplace;
                           }
                           $index_i += 3;

                   }   # the end of while ($index_i < $doc_num*3+3) condition

                   #collect missing_words' probabilitis of all the documents
                   $missing_p = log(1/($doclen+$num_unique_terms));
                   $laplace_back_p{$line} = $missing_p;
              } #the end of if $total_f > 0 condition

              splice (@temp,0);   #re-use the array @temp
       } # the end of while(<FH>)

       #-------------JELINEK-MERCER background probabilities making up----------
       #make up the background probabilities for all the document
       foreach $key (keys (%jm_back_p)){
                foreach $kk (keys %{$jm_score_hash}){
                         if(!exists $jm_score_hash->{$kk}->{$key}){
                            $jm_score_hash->{$kk}->{$key} = $jm_back_p{$key};
                         }
                }
       }

       #re-use the %jm_back_p hash
       foreach $key (keys (%jm_back_p)){
                delete $jm_back_p{$key};
       }

       # --- JELINEK-MERCER Final score computing -------
       #compute the final scores for the documents and put them into
       #a new hash, called jm_final_score
       $product = 0;
       foreach $key (keys %{$jm_score_hash}){
                while(($nkey, $nvalue)= each(%{$jm_score_hash->{$key}})){
                        $product +=$nvalue;
                }
                $jm_final_score{$key} = $product;
                #delete $score_hash->{$key};
                $product = 0; #reset the value of $product
       }

       #re-use a hash of hashes
       foreach $key (keys %{$jm_score_hash}){
                foreach $kkey (keys %{$jm_score_hash->{$key}}){
                         delete $jm_score_hash->{$key}->{$kkey};
                }
       }

       #-------------Laplace background probabilities making up-----------
       #make up the missing_words probabilities for all the documents
       foreach $key (keys (%laplace_back_p)){
                foreach $kk (keys %{$laplace_score_hash}){
                         if(!exists $laplace_score_hash->{$kk}->{$key}){
                            $laplace_score_hash->{$kk}->{$key} = $laplace_back_p{$key};
                         }
                }
       }

       #re-use the %laplace_back_p hash
       foreach $key (keys (%laplace_back_p)){
                delete $laplace_back_p{$key};
       }

       # --- Laplace Final score computing -------
       #compute the final scores for the documents and put them into
       #a new hash, called laplace_final_score
       $product = 0;
       foreach $key (keys %{$laplace_score_hash}){
                while(($nkey, $nvalue)= each(%{$laplace_score_hash->{$key}})){
                        #  print "KKK $nkey VVV $nvalue\n";
                        $product +=$nvalue;
                        #delete $laplace_score_hash->{$key}->{$nkey};
                        #print T "Ppp $product\n";
                }
                $laplace_final_score{$key} = $product;
                # print T "$key,$laplace_final_score{$key}\n";
                $product = 0; #reset the value of $product
       }

       #re-use a hash of hashes
       foreach $key (keys %{$laplace_score_hash}){
                foreach $kkey (keys %{$laplace_score_hash->{$key}}){
                         delete $laplace_score_hash->{$key}->{$kkey};
                }
       }

       print "Finished Models Processing...\n";

       # ---Sorting the score hashes, Metasearching ----------------

       #sorting a Hash by score by value in decending Order
       # --- Laplace ----
       sub laplace_desc_score_sort {
           $laplace_final_score{$b} <=> $laplace_final_score{$a};
       }
       # --- BM25---
       sub bm_desc_score_sort {
           $bm_score_hash{$b} <=> $bm_score_hash{$a};
       }
       # --- JELINEK-MERCER ----
       sub jm_desc_score_sort {
           $jm_final_score{$b} <=> $jm_final_score{$a};
       }
       # --- Okapi tf ---
       sub oktf_desc_score_sort {
           $oktf_score_hash{$b} <=> $oktf_score_hash{$a};
       }
       # --- Okapi tf-idf ---
       sub idf_desc_score_sort {
           $tf_idf_score_hash{$b} <=> $tf_idf_score_hash{$a};
       }

       # --- CombSUM ---
       sub combsum_desc_score_sort {
           $combsum{$b} <=> $combsum{$a};
       }

       # ----- get max and min to normalize ---
        $rank_num = 1;
       foreach $key (sort idf_desc_score_sort(keys(%tf_idf_score_hash))){
                if ($rank_num <1001){
                     if ($rank_num == 1){
                          $idf_max = $tf_idf_score_hash{$key};
                     }
                     if ($rank_num == 1000){
                          $idf_min = $tf_idf_score_hash{$key};
                     }
                     $rank_num++;
                }
       }

        $rank_num = 1;
       foreach $key (sort oktf_desc_score_sort(keys(%oktf_score_hash))){
               if ($rank_num <1001){
                     if ($rank_num == 1){
                          $tf_max = $oktf_score_hash{$key};
                     }
                     if ($rank_num == 1000){
                          $tf_min = $oktf_score_hash{$key};
                     }
                     $rank_num++;
                }
       }

        $rank_num = 1;
       foreach $key (sort jm_desc_score_sort(keys(%jm_final_score))){
                if ($rank_num <1001){
                     if ($rank_num == 1){
                          $jm_max = $jm_final_score{$key};
                     }
                     if ($rank_num == 1000){
                          $jm_min = $jm_final_score{$key};
                     }
                     $rank_num++;
                }
       }

       $rank_num = 1;
       foreach $key (sort bm_desc_score_sort(keys(%bm_score_hash))){
                if ($rank_num <1001){
                     if ($rank_num == 1){
                          $bm_max = $bm_score_hash{$key};
                     }
                     if ($rank_num == 1000){
                          $bm_min = $bm_score_hash{$key};
                     }
                     $rank_num++;
                }
       }

       $rank_num = 1;
       foreach $key (sort laplace_desc_score_sort(keys(%laplace_final_score))){
                if ($rank_num <1001){
                     if ($rank_num == 1){
                          $laplace_max = $laplace_final_score{$key};
                     }
                     if ($rank_num == 1000){
                          $laplace_min = $laplace_final_score{$key};
                     }
                     $rank_num++;
                }
       }

       # --- Get the truncated ranked lists ----
       $rank_num = 1;
       foreach $key (sort idf_desc_score_sort(keys(%tf_idf_score_hash))){
             if ($rank_num < 1001){
                     $score = ($tf_idf_score_hash{$key}-$idf_min)/($idf_max-$idf_min);
                     $combsum{$key} = $score*2.0;
                     $rank_num++;
                }
       }

       $rank_num = 1;
       foreach $key (sort oktf_desc_score_sort(keys(%oktf_score_hash))){
                if ($rank_num < 1001){
                     $score = ($oktf_score_hash{$key}-$tf_min)/($tf_max-$tf_min);
                     if (exists $combsum{$key}){
                         $combsum{$key} += $score*1.5;
                     }
                     else{
                          $combsum{$key} = $score*1.5;
                     }
                     $rank_num++;
                }
       }

       $rank_num = 1;
       foreach $key (sort bm_desc_score_sort(keys(%bm_score_hash))){
            if ($rank_num < 1001){
                     $score = ($bm_score_hash{$key}-$bm_min)/($bm_max-$bm_min);
                     if (exists $combsum{$key}){
                         $combsum{$key} += $score;
                     }
                     else{
                          $combsum{$key} = $score;
                     }
                     $rank_num++;
                }
       }

       $rank_num = 1;
       foreach $key (sort jm_desc_score_sort(keys(%jm_final_score))){
            if ($rank_num < 1001){
                     $score = ($jm_final_score{$key}-$jm_min)/($jm_max-$jm_min);
                     if (exists $combsum{$key}){
                         $combsum{$key} += $score;
                     }
                     else{
                          $combsum{$key} = $score;
                     }
                     $rank_num++;
                }
       }
       $rank_num = 1;
       foreach $key (sort laplace_desc_score_sort(keys(%laplace_final_score))){
            if ($rank_num < 1001){
                     $score = ($laplace_final_score{$key}-$laplace_min)/($laplace_max-$laplace_min);
                     if (exists $combsum{$key}){
                         $combsum{$key} += $score;
                     }
                     else{
                          $combsum{$key} = $score;
                     }
                     $rank_num++;
                }
       }
        # ------- Metasearch: CombSUM -------
        $rank_num = 1;
        foreach $key (sort combsum_desc_score_sort(keys(%combsum))){
                   if ($rank_num < 1001){
                     $score = $combsum{$key};
                     printf FILE "%d Q0 %s %d %f Exp\n",
                            $query_num[$query_i],$id_map{$key},$rank_num,$score;
                     $rank_num++;
                   }
          }

       #delete the all the value in hashes, in order to re-use
       # -- Laplace ---
       foreach $key1 (keys(%laplace_final_score)){
                delete $laplace_final_score{$key1};
       }
       # -- BM25 ---
       foreach $key1 (keys(%bm_score_hash)){
                delete $bm_score_hash{$key1};
       }
       # -- QF HASH ---
       foreach $key1 (keys(%qf)){
                delete $qf{$key1};
       }
       # -- JM ---
       foreach $key1 (keys(%jm_final_score)){
                delete $jm_final_score{$key1};
       }
       # Okapi tf
       foreach $key1 (keys(%oktf_score_hash)){
                delete $oktf_score_hash{$key1};
       }
       # tf-idf
       foreach $key1 (keys(%tf_idf_score_hash)){
                delete $tf_idf_score_hash{$key1};
       }
        # combsum
       foreach $key1 (keys(%combsum)){
                delete $combsum{$key1};
       }

       #tracking the process
       printf "Complete Query %s\n",$query_num[$query_i];
       $query_i++;
}
close(FH);
close(FILE);
#close(T);