function[b_model,b_ind,b_loading,exp_var] = eeg_kMeans(eeg,n_mod,reruns,max_n,flags,chanloc)
% EEG_MOD Create the EEG model I'm working with
%
% function[b_model,b_ind,b_loading,exp_var] = eeg_mod_r(eeg,n_mod,reruns,max_n)

% input arguments
% eeg = the input data (number of time instances * number of channels)
% n_mod = the number of microstate clusters that you want to extract
% reruns = the number of reiterations (use about 20)
% max_n = maximum number of eeg timepoints used for cluster indentification

% output arguments
% b_model = cluster centers (microstate topographies)
% b_ind = cluster assignment for each moment of time
% b_loading = Amplitude of the assigned cluster at each moment in time
% exp_var = explained variance of the model

if (size(n_mod,1) ~= 1)
	error('Second argument must be a scalar')
end

if (size(n_mod,2) ~= 1)
	error('Second argument must be a scalar')
end

[n_frame,n_chan] = size(eeg);

if nargin < 3
    reruns = 1;
end

if nargin < 4
    max_n = n_frame;
end

if isempty(max_n)
    max_n = n_frame;
end

if (max_n > n_frame)
    max_n = n_frame;
end

if ~contains(flags,'p')
    pmode = 0;
else
    pmode = 1;
end

org_data = eeg;

newRef = eye(n_chan);
if contains(flags,'a')
    newRef = newRef -1/n_chan;
end

UseEMD = false;
if contains(flags,'e')
    UseEMD = true;
end

eeg = eeg*newRef;

if contains(flags,'n')
    eeg = NormDim(eeg,2);
end

best_fit = 0;

if contains(flags,'b')
    h = waitbar(0,sprintf('Computing %i clusters, please wait...',n_mod));
else
    h = [];
    nSteps = 20;
    step = 0;
    fprintf(1, 'k-means clustering(k=%i): |',n_mod);
    strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '|   0%%']);
    tic
end

for run = 1:reruns
    if isempty(h)
        [step, strLength] = mywaitbar(run, reruns, step, nSteps, strLength);
    else
        t = sprintf('Run: %i / %i',run,reruns);
        set(h,'Name',t);
        waitbar(run/reruns,h);
    end
    if nargin > 3
        idx = randperm(n_frame);
        eeg = org_data(idx(1:max_n),:);
    end

    idx = randperm(max_n);
    model = eeg(idx(1:n_mod),:);
    model   = NormDim(model,2)*newRef;					% Average Reference, equal variance of model

    o_ind   = zeros(max_n,1);							% Some initialization
%	ind     =  ones(max_n,1);
	count   = 0;
    covmat = eeg*model';							    % Get the unsigned covariance 
    
    if pmode
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,false),[],2);
        else
            [~,ind] =  max(covmat,[],2);				
        end     % Look for the best fit
    else
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,true),[],2);
        else
            [~,ind] =  max(abs(covmat),[],2);				% Look for the best fit
        end
    end
        
    
    % TODO TEMP COUNT LIMIT
    conv_limit = 10000;
    while count < conv_limit && any(o_ind - ind)
        count   = count+1;
        if count == conv_limit
            warning("K-Means Didn't converge in 10000 iterations");
        end
        o_ind   = ind;
%        if pmode
%            covm    = eeg * model';						% Get the unsigned covariance matrix
%        else
%            covm    = abs(eeg * model');						% Get the unsigned covariance matrix
%        end
%        [c,ind] =  max(covm,[],2);				            % Look for the best fit

        for i = 1:n_mod
            idx = find (ind == i);
            if pmode
                model(i,:) = mean(eeg(idx,:));
            else
                cvm = eeg(idx,:)' * eeg(idx,:);
                [v,d] = eigs(double(cvm),1);
                model(i,:) = v(:,1)';
            end
        end
		model   = NormDim(model,2)*newRef;						% Average Reference, equal variance of model
        covmat = eeg*model';							% Get the unsigned covariance 
        if pmode
            if UseEMD == true
                [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,false),[],2);
            else
                [~,ind] =  max(covmat,[],2);				
            end     % Look for the best fit
        else
            if UseEMD == true
                [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,true),[],2);
            else
                [~,ind] =  max(abs(covmat),[],2);				% Look for the best fit
            end
        end
    end % while any

    % average reference eeg in case it was not already done
    newRef = eye(n_chan);
    newRef = newRef -1/n_chan;
    org_data = org_data*newRef;
    covmat    = org_data*model';							% Get the unsigned covariance 
    if pmode
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(org_data),double(model),chanloc,chanloc,false),[],2);
            loading = zeros(size(ind));
            for t = 1:numel(ind)
                loading(t) = covmat(t,ind(t));
            end
        else
            [loading,ind] =  max(covmat,[],2);				% Look for the best fit
        end
    else
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(org_data),double(model),chanloc,chanloc,true),[],2);
            loading = zeros(size(ind));
            for t = 1:numel(ind)
                loading(t) = abs(covmat(t,ind(t)));
            end
        else
            [loading,ind] =  max(abs(covmat),[],2);				% Look for the best fit
        end
    end
 
    tot_fit = sum(loading);
    if (tot_fit > best_fit)
        b_model   = model;
        b_ind     = ind;
        b_loading = loading; %/sqrt(n_chan);
        best_fit  = tot_fit;
    end    
end % for run = 1:reruns

% Individual GEVs
IndGEVnum = zeros(1, n_mod);
for i = 1:n_mod
    clustMembers = (b_ind == i);
    IndGEVnum(i) = sum((b_loading(clustMembers)/sqrt(n_chan)).^2);
end
exp_var = IndGEVnum/sum(vecnorm(org_data').^2);

if isempty(h)
    mywaitbar(reruns, reruns, step, nSteps, strLength);
    fprintf('\n');
else
    close(h);
end