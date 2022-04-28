% function compute within-group dispersion matrix for a specific cluster
% solution
function TW = eeg_TW(IndSamples, ClustLabels)

    % get number of clusters
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
        TW = nan;
        return;
    end

    nChan = size(IndSamples, 1);
              
    W = zeros(nChan, nChan);
    for i = 1:numClusts
      members = (ClustLabels == clusters(i));
      if any(members)
          clustMembers = IndSamples(:, members);
          centroid = mean(clustMembers, 2);
          numSamples = size(clustMembers, 2);
          for j = 1:numSamples
              W = W + (clustMembers(:, j) - centroid)*(clustMembers(:, j) - centroid)';
          end
      end
    end

    TW = trace(W);

end