function [ClusterCenter,Assignment,Loading,ExplainedVariance] = eeg_dbScan(eeg,Epsilon,MinPts,Max_Clust, DownSamplingSize,flags)
% EEG_MOD Create the EEG model I'm working with
%
% function [b_model,b_ind,b_loading,exp_var] = eeg_dbClustering(eeg,Epsilon,MinPnts,max_n,flags)



% input arguments
% eeg              = the input data (number of time instances * number of channels)
% Epsilon          = The minimal correlation 
% RelMinPnts       = minimal percentage of all datapoints necessary for a cluster
% DownSamplingSize = maximum number of eeg timepoints used for cluster indentification
% Max_Clust        = maximum number of clusters to identify

% output arguments
% ClusterCenter     = cluster centers (microstate topographies)
% Assignment        = cluster assignment for each moment of time
% Loading           = Amplitude of the assigned cluster at each moment in time
% ExplainedVariance = explained variance of the model

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

    if (numel(Epsilon) ~= 1)
	    error('Second argument must be a scalar')
    end

    if (numel(MinPts) ~= 1)
	    error('Third argument must be a scalar')
    end

    [n_frame,n_chan] = size(eeg);

    if nargin < 3
        MinPts = 0.05;
    end

    if nargin < 4
        Max_Clust = [];
    end

    if nargin < 5
        DownSamplingSize = n_frame;
    end


    if nargin < 6
        flags = '';
    end

    if isempty(DownSamplingSize)
        DownSamplingSize = n_frame;
    end

    if (DownSamplingSize > n_frame)
        DownSamplingSize = n_frame;
    end

    if ~contains(flags,'p')
        pmode = 0;
    else
        pmode = 1;
    end

    if isempty(Max_Clust)
        Max_Clust = n_frame;
    end


    % Average reference
    newRef = eye(n_chan);
    newRef = newRef -1/n_chan;
    eeg = double(eeg*newRef);

    if DownSamplingSize < Max_Clust
        ClusterCenter = [];
        return;
    end

    if DownSamplingSize < n_frame    % We do a downsampling
        SelectedMaps = randperm(n_frame);
    else
        SelectedMaps = 1:n_frame;
    end

    % This is the correlation matrix
    CorMat = corr(eeg(SelectedMaps(1:DownSamplingSize),:)');

    % We fix inverted polarities
    if pmode == false
        CorMat = abs(CorMat);
    end

    ClassIndex = 1;
    Assignment   = ones(n_frame,1) * -1;




    
    % We loop until we have all the clusters we want
    while(ClassIndex <= Max_Clust)
        % How many neighbors (defined by having a spatial correlation larger
        % than Epsilon) does each map have?
        nNeighbors = sum(CorMat >= Epsilon,2);
    
        % The next cluster center is the map with most neighbors
        [Cnt,NextClusterPrototype] = max(nNeighbors);
    
        % If it does not have enough neighbors, we give up
        if Cnt < ceil(MinPts * DownSamplingSize) 
            break;
        end

        % Otherwise, we store it as cluster center
        ClusterCenter(ClassIndex,:) = eeg(SelectedMaps(NextClusterPrototype),:);

        % And define it's neighbors as cluster members
        Members = CorMat(NextClusterPrototype,:) >= Epsilon;
        Assignment(Members) = ClassIndex;

        % We mask sucessfully assigned maps from the further analysis
        % Can't become new clusters
        CorMat(Members,:) = -inf;
        % and can't be assigned to new clusters
        CorMat(:,Members) = -inf;
        % Some very preliminary progress display
        [Cnt ceil(MinPts * DownSamplingSize)]
    
        % and we're ready to identify the next cluster
        ClassIndex = ClassIndex + 1;
    end

    % If we downsampled, extent the assignment to all the data
    if DownSamplingSize < n_frame    
        CorMat = corr(eeg',ClusterCenter');
   
        if pmode == false
            CorMat = abs(CorMat);
        end
        [m,Assignment] = max(CorMat,[],2);
        Assignment(m < Epsilon) = -1;
    end

    % and Update the template maps based on all class members
    n_mod = max(Assignment);

    for i = 1:n_mod
        idx = find (Assignment == i);
        if pmode
            ClusterCenter(i,:) = mean(eeg(idx,:));
        else
            cvm = eeg(idx,:)' * eeg(idx,:);
            [v,~] = eigs(double(cvm),1);
            ClusterCenter(i,:) = v(:,1)';
        end
    end

    % We still need to get the explained variance
    ClusterCenter = NormDimL2(ClusterCenter,2);

    covmat = eeg*ClusterCenter';							    % Get the unsigned covariance 

    Loading = zeros(numel(Assignment),1);

    for i = 1:n_mod
        idx = Assignment == i;
        Loading(idx) = abs(covmat(idx,i));
    end

    IndGEVnum = zeros(n_mod,1);

    for i = 1:n_mod
        clustMembers = (Assignment == i);
        IndGEVnum(i) = sum(Loading(clustMembers).^2);
    end
    ExplainedVariance = IndGEVnum/sum(vecnorm(eeg').^2);
end
