% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."

function [b_model,exp_var] = eeg_AAHC(eeg,n_mod,ProgBar, IgnorePolarity, Normalize)

    if nargin < 3;  ProgBar = true; end
    if nargin < 4;  IgnorePolarity = false; end
    if nargin < 5;  Normalize = true; end
    [n_frame,n_chan] = size(eeg);

    h = eye(n_chan)-1/n_chan;
    eeg = eeg*h;									% Average reference of data 

    % Initally, all maps are clusters
    Cluster = L2NormDim(eeg,2);

    if Normalize == true
        eeg = L2NormDim(eeg,2);
    end
    
        
    if (ProgBar == true)
        hndl = waitbar(0,sprintf('Fitting %i-%i microstates (AAHC), please wait...',n_mod(1),n_mod(end)));
    else
        nSteps = 20;
        step = 0;
        fprintf(1, 'AAHC clustering(): |');
        strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '|   0%%']);
        tic
    end
    
    Assignment = 1:n_frame;
    nClusters = size(Cluster,1);
    
    while (nClusters) > min(n_mod)
%        ClusterSimilarity = Cluster*Cluster';
        

%        ClusterSimilarity = ClusterSimilarity - ClusterSimilarity .* eye(nClusters);

%        if (IgnorePolarity == true);    ClusterSimilarity = abs(ClusterSimilarity); end
        % We're not interested in self-similarity

        % Now find the two most similar clusters
%        [MxSim,index] = max(ClusterSimilarity(:));
%        [i,j] = ind2sub(size(ClusterSimilarity),index);
        
        dists = pdist(Cluster,"euclidean");
        c = 1 - (dists.^2) / 2;
        if IgnorePolarity == true
            c = abs(c);
        end
        [mx,idx] = max(c);
        [i,j] = triind2sub(size(Cluster),idx);
        ClusterToMerge1 = min(i,j);
        ClusterToMerge2 = max(i,j);

        fprintf(1,'%i: %f (i: %i j:%i)\n',nClusters,mx,i,j);

        % And these are it's members, to become orphans
        Orphans = Assignment == ClusterToMerge1 | Assignment == ClusterToMerge2; % These are the orphans
        % So we compute one new cluster based on all the orphans
        Cluster(ClusterToMerge1,:) = UpdateClusterCenter(eeg(Orphans,:),IgnorePolarity);

        % And make the other one disappear
        Cluster(ClusterToMerge2,:) = [];   
        % The assignment has to be adjusted
        Assignment(Assignment > ClusterToMerge2) = Assignment(Assignment > ClusterToMerge2) - 1;
    
        % Now let's see who's going at adopting the orphans
        Fit = eeg(Orphans,:) * Cluster';  % nOrphans x nClusters
        if (IgnorePolarity == true);    Fit = abs(Fit); end
        [~,NewAssignment] = max(Fit,[],2);  
        Assignment(1,Orphans) = NewAssignment;  % And do the assignment
    
        %So now some of the clusters need an update
        ClusterToUpdate = unique(NewAssignment);
        for f = 1:numel(ClusterToUpdate)  % Some cluster center need an update
            ClusterMembers = Assignment == ClusterToUpdate(f);
            Cluster(ClusterToUpdate(f),:) = UpdateClusterCenter(eeg(ClusterMembers,:),IgnorePolarity);

        end
        nClusters = size(Cluster,1);
    
        gfp = std(Cluster,1,2);
        
        if any(gfp < 0.05)
            Clustkeyboard;
        end

        prc = 1-(nClusters+min(n_mod))/n_frame;
    
        if (rem(nClusters,10) == 0)
            if ProgBar == true
                waitbar(prc,hndl);
                set(hndl,'Name',sprintf('Remaining time: %01.0f:%02.0f min',floor(toc()*(1/prc)/60),rem(toc()*(1/prc-1),60)));
            else
                [step, strLength] = mywaitbar(n_frame - nClusters, n_frame, step, nSteps, strLength);
            end
        end
        if numel(n_mod) > 1
            idx = find(n_mod == nClusters);
            if numel(idx) > 0
                b_model{idx} = Cluster;
                exp_var{idx} = GEV' / TotalVar;
            end
        end
    end

    if numel(n_mod) == 1
        b_model{1} = Cluster;
        exp_var{1} = GEV' / TotalVar;
    end

    if (ProgBar == true)
        close(hndl);
    else
        mywaitbar(n_frame, n_frame, step, nSteps, strLength);
        fprintf(1,'\n');
    end
end


function ClusterCenter = UpdateClusterCenter(Maps,IgnorePolarity)
    if (IgnorePolarity == true)
        [pc1,~] = eigs(cov(Maps,1),1);
        ClusterCenter = L2NormDim(pc1',2);
    else
        ClusterCenter = L2NormDim(mean(Maps,1),2);
    end
end


function [i,j] = triind2sub(siz,ind)
%TRIIND2SUB Convert triangular indices to matrix subscripts
%   This function is for use with pdist which calculates distances between
%   pairs of points in an m-by-n matrix.  Results are returned as a row
%   vector in order
%       (2,1), (3,1), ..., (m,1), (3,2), ..., (m,2), ..., (m,m�1))
%   triind2sub takes the size of the input matrix to pdist and an array
%   of indices of the distances returned.  The result is two arrays of the
%   same dimensions of the indices containing the column and row
%   subscripts.  Since the results of pdist represent a strictly lower
%   triangular matrix, the column subscripts in i will be greater than the
%   corresponding row subscripts in j
%
%   Example:
%      square = [0 0; 0 1; 1 1; 1 0];
%      % find the distances between the corners of the unit square
%      dists = pdist(square);
%      % report the pairs of points with maximum separation
%      [col, row] = triind2sub(size(square), find(dists == max(dists)))
%      % report the pairs of points with minimum separation
%      [col, row] = triind2sub(size(square), find(dists == min(dists)))
%
%   The approach above can avoid the use of the squareform function while
%   using less space and avoiding duplicate results.
%
%   See also PDIST, SQUAREFORM, SUB2TRIIND.
% Copyright 2017 James Ashton
n = siz(1); % number of columns given to pdist
ntri = n * (n - 1) / 2; % number of results returned by pdist
ind = (ntri + 1) - ind; % reverse the order
j = ceil((sqrt(ind * 8 + 1) - 1) / 2); % inverse of ind = j*(j+1)/2
i = n + 1 + j .* (j - 1) ./ 2 - ind;
j = n - j;
end
