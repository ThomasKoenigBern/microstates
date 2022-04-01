% modified version of getDB function in DaviesBouldinEvaluation.m from
% Machine Learning and Statistics toolbox - uses absolute spatial
% correlation as distance function instead of euclidean distance

function DB = eeg_DaviesBouldin(IndSamples, ClustLabels, IgnorePolarity)

    % Performs element-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) between matrices A and B
    function corrDist = elementCorrDist(A,B)
        % average reference
        A = A - mean(A, 1);
        B = B - mean(B, 1);

        % get correlation
        A = A./sqrt(sum(A.^2, 1));
        B = B./sqrt(sum(B.^2, 1));
        corr = sum(A.*B, 1);           

        % corr dist
        if (IgnorePolarity) 
            corrDist = 1 - abs(corr);
        else 
            corrDist = 1 - corr; 
        end
    end

    % Performs pair-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) for every pair of columns in matrix A
    function corrDist = pairCorrDist(A)
        c = corr(A);
        if (IgnorePolarity) 
            corrDist = 1 - abs(c);
        else 
            corrDist = 1 - c; 
        end
    end

      clusters = unique(ClustLabels);
      numClusts = length(clusters);
      if numClusts == 1
          DB = nan;
          return;
      end
      centroids = NaN(size(IndSamples,1), numClusts);

      aveWithinD= zeros(numClusts,1);
      for i = 1:numClusts
          members = (ClustLabels == clusters(i));
          if any(members)
              centroids(:, i) = mean(IndSamples(:, members), 2) ;
              %average distance of each observation to the centroids, using
              %1 - absolute spatial correlation as distance function
              aveWithinD(i) = mean(elementCorrDist(IndSamples(:, members), centroids(:, i)));
          end
      end
        
      interD = pairCorrDist(centroids);
      R = zeros(numClusts);
      for i = 1:numClusts
          for j=i+1:numClusts %j>i
              R(i,j)= (aveWithinD(i)+aveWithinD(j))/ interD(i,j);
          end
      end
      R=R+R';

      RI = max(R,[],1);
      DB = mean(RI);
end 