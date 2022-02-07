% calculates dispersion (W): measure of average distance between members 
% of the same cluster, using 1 - absolute spatial correlation as distance
% function

function W = eeg_Dispersion(templateMaps,clusts)

      function dist = distfun(XI,XJ)
        dist = (1-abs(MyCorr(XI',XJ')));
      end

      clusters = unique(clusts);
      numClusts = length(clusters);
        
      W = 0;
      for i = 1:numClusts
          members = (clusts == clusters(i));
          if any(members)
              % sum of squares between members of cluster
              S = sum(pdist(templateMaps(members,:)));
              W = W + S/(2*nnz(members));
          end
      end

end