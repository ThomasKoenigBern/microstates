%pop_CombMSTemplates() interactively averages microstate across EEGs
%
% This is not a simple averaging, but a permute and average loop that
% optimizes the order of microstate classes in the individual datasets for
% maximal communality before averaging!
%
% Usage: >> [EEGOUT,com] = pop_CombMSTemplates(AllEEG, CURRENTSET, DoMeans, ShowWhenDone, MeanSetName)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "CURRENTSET" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked.
%
%   "DoMeans"
%   -> True if you want to grand-average microstate maps already averaged
%   over datasets, false otherwise. Default is false (no GUI based choice).
%
%   "Show maps when done" / ShowWhenDone
%   -> Show maps when done
%
%   "Name of mean" / MeanSetName
%   -> Name of the new dataset returned by EEGOUT
%
% Output:
%
%   "EEGOUT" 
%   -> EEG structure with the EEG containing the new cluster centers
%
%   "com"
%   -> Command necessary to replicate the computation
%
% Author: Thomas Koenig, University of Bern, Switzerland, 2016
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2016
% thomas.koenig@puk.unibe.ch
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [AllEEG, EEGOUT,com] = pop_CombMSTemplates(AllEEG, CURRENTSET, DoMeans, ShowWhenDone, MeanSetName, IgnorePolarity)

    if nargin < 3;  DoMeans = false;            end
    if nargin < 4;  ShowWhenDone = false;       end
    if nargin < 5;  MeanSetName = 'GrandMean';  end
    if nargin < 6;  IgnorePolarity = true;      end
    if nargin < 7;  SortMaps = false;           end
    com = '';
    EEGOUT = [];
    
    % find the list of all channels, and make sure we have the individual
    % maps with sufficiently identical parameters
    % -------------------------------------------
    if numel(CURRENTSET) == 1 
        nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
        HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
        if DoMeans == true
            nonempty(~HasChildren) = [];
        else
            nonempty(HasChildren) = [];
        end
        AvailableSets = {AllEEG(nonempty).setname};
            
        res = inputgui('title','Average microstate maps across recordings',...
        'geometry', {1 1 1 1 1 1 1}, 'geomvert', [1 1 4 1 1 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for averaging'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', MeanSetName,'tag','MeanName' } ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            { 'Style', 'checkbox', 'string' 'Show maps when done' 'tag' 'Show_Maps'    ,'Value', ShowWhenDone }});
     
        if isempty(res); return; end
        MeanSetName = res{2};
        SelectedSet = nonempty(res{1});
        IgnorePolarity = res{3};
        ShowWhenDone = res{4};  
    else
        if nargin < 5
            res = inputgui('title','Average microstate maps across recordings',...
                'geometry', {1 1 1 1}, 'geomvert', [1 1 1 1], 'uilist', { ...
                { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
                { 'Style', 'edit', 'string', MeanSetName,'tag','MeanName' } ...
                { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
                { 'Style', 'checkbox', 'string' 'Show maps when done' 'tag' 'Show_Maps'    ,'Value', ShowWhenDone }});
        
            if isempty(res); return; end
    
            MeanSetName = res{1};
            IgnorePolarity = res{2};
            ShowWhenDone = res{3};
        end    
        SelectedSet = CURRENTSET;
    end

    if numel(SelectedSet) < 2
        errordlg2('You must select at least two sets of microstate maps','Combine microstate maps');
        return;
    end

    if ~isfield(AllEEG(SelectedSet(1)),'msinfo')
        errordlg2(sprintf('Microstate info not found in dataset %',AllEEG(SelectedSet(1)).setname), 'Combine microstate maps');
        return;
    end

    MinClasses     = AllEEG(SelectedSet(1)).msinfo.ClustPar.MinClasses;
    MaxClasses     = AllEEG(SelectedSet(1)).msinfo.ClustPar.MaxClasses;
    tempIPolarity  = AllEEG(SelectedSet(1)).msinfo.ClustPar.IgnorePolarity;
    GFPPeaks       = AllEEG(SelectedSet(1)).msinfo.ClustPar.GFPPeaks;
    
     if ~isfield(AllEEG(SelectedSet(1)).msinfo.ClustPar,'UseEMD')
        UseEMD = false;
     else
         UseEMD = AllEEG(SelectedSet(1)).msinfo.ClustPar.UseEMD;
     end
    
    allchans  = { };
    children  = cell(length(SelectedSet),1);
    keepindex = 0;

    for index = 1:length(SelectedSet)
        if ~isfield(AllEEG(SelectedSet(index)),'msinfo')
            errordlg2(sprintf('Microstate info not found in dataset %',AllEEG(SelectedSet(index)).setname), 'Combine microstate maps'); 
            return;
        end
    
        if  MinClasses     ~= AllEEG(SelectedSet(index)).msinfo.ClustPar.MinClasses || ...
            MaxClasses     ~= AllEEG(SelectedSet(index)).msinfo.ClustPar.MaxClasses || ...
            tempIPolarity  ~= AllEEG(SelectedSet(index)).msinfo.ClustPar.IgnorePolarity || ...
            GFPPeaks       ~= AllEEG(SelectedSet(index)).msinfo.ClustPar.GFPPeaks
            errordlg2('Microstate parameters differ between datasets','Combine microstate maps');
            return;
        end
    
        children(index) = {AllEEG(SelectedSet(index)).setname};
        tmpchanlocs = AllEEG(SelectedSet(index)).chanlocs;
        tmpchans = { tmpchanlocs.labels };
        allchans = unique_bc([ allchans {tmpchanlocs.labels}]);

        if length(allchans) == length(tmpchans)
            keepindex = index;
        end
    end
    if keepindex
        tmpchanlocs = AllEEG(SelectedSet(keepindex)).chanlocs; 
    %    allchans = { tmpchanlocs.labels }; 
    end

    % Ready to go, it seems. Now we create a matrix of subject x classes x
    % channels

    msinfo.children = children;
    msinfo.ClustPar   = AllEEG(SelectedSet(1)).msinfo.ClustPar;
  
    for n = MinClasses:MaxClasses
        MapsToSort = nan(numel(SelectedSet),n,numel(tmpchanlocs));
        % Here we go to the common set of channels
        for index = 1:length(SelectedSet)
            LocalToGlobal = MakeResampleMatrices(AllEEG(SelectedSet(index)).chanlocs,tmpchanlocs);
            MapsToSort(index,:,:) = AllEEG(SelectedSet(index)).msinfo.MSMaps(n).Maps * LocalToGlobal';
        end
    % We sort out the stuff
%        BestMeanMap = PermutedMeanMaps(MapsToSort,~IgnorePolarity);
        BestMeanMap = PermutedMeanMaps(MapsToSort,~IgnorePolarity,tmpchanlocs,[],UseEMD); % debugging only
        msinfo.MSMaps(n).Maps = BestMeanMap;
        msinfo.MSMaps(n).ExpVar = NaN;
        msinfo.MSMaps(n).ColorMap = lines(n);
        msinfo.MSMaps(n).SortedBy = 'none';
        msinfo.MSMaps(n).SortMode = 'none';
        msinfo.MSMaps(n).SpatialCorrelation = [];
    end
    
    EEGOUT = eeg_emptyset();
    EEGOUT.chanlocs = tmpchanlocs;
    EEGOUT.data = zeros(numel(EEGOUT.chanlocs),MaxClasses,MaxClasses);
    EEGOUT.msinfo = msinfo;
    
    for n = MinClasses:MaxClasses
        EEGOUT.data(:,1:n,n) = msinfo.MSMaps(n).Maps';
    end
    
    EEGOUT.setname     = MeanSetName;
    EEGOUT.nbchan      = size(EEGOUT.data,1);
    EEGOUT.trials      = size(EEGOUT.data,3);
    EEGOUT.pnts        = size(EEGOUT.data,2);
    EEGOUT.srate       = 1;
    EEGOUT.xmin        = 1;
    EEGOUT.times       = 1:EEGOUT.pnts;
    EEGOUT.xmax        = EEGOUT.times(end);
    
    [AllEEG, EEGOUT, CURRENTSET] = pop_newset(AllEEG, EEGOUT, CURRENTSET,'gui','off'); 
    
    % Sort 3-6 cluster solutions using 2002 normative maps and 7
    % cluster solution with Custo 2017 maps
    if (MinClasses < 3 && MaxClasses > 2) || (MinClasses > 2)
        [AllEEG, EEGOUT, ~] = pop_SortMSTemplates(AllEEG, CURRENTSET, DoMeans, -1, "Norms NI2002", 1);
    end
    if (MinClasses <= 7 && MaxClasses >= 7)
        AllEEG(CurrentSet).msinfo = TheEEG.msinfo;
        [AllEEG, EEGOUT, ~] = pop_SortMSTemplates(AllEEG, CURRENTSET, DoMeans, -1, "Custo2017", 1);
    end

    % Compute spatial correlations between child maps and permuted mean
    % maps
    for i = 1:length(SelectedSet)
        for n = MinClasses:MaxClasses
            % Make sure the individual maps are sorted by published
            % template first
            if (n >= 3 && n <= 6)
                if ~strcmp(AllEEG(SelectedSet(i)).msinfo.MSMaps(n).SortedBy, "Norms NI2002")
                    [AllEEG, ~, ~] = pop_SortMSTemplates(AllEEG, SelectedSet(i), 0, -1, "Norms NI2002", IgnorePolarity, n);
                end
            elseif n == 7
                if ~strcmp(AllEEG(SelectedSet(i)).msinfo.MSMaps(n).SortedBy, "Custo2017")
                    [AllEEG, ~, ~] = pop_SortMSTemplates(AllEEG, SelectedSet(i), 0, -1, "Custo2017", IgnorePolarity, n);
                end
            end

            % compute and store spatial correlations in child structure
            spCorr = elementCorr(AllEEG(SelectedSet(i)).msinfo.MSMaps(n).Maps', EEGOUT.msinfo.MSMaps(n).Maps', IgnorePolarity);
            AllEEG(SelectedSet(i)).msinfo.MSMaps(n).ParentSet = MeanSetName;
            AllEEG(SelectedSet(i)).msinfo.MSMaps(n).ParentSpatialCorrelation = spCorr;
        end
    end

    if ShowWhenDone == true
        pop_ShowIndMSMaps(EEGOUT);
    end

    % Remove the new mean set from ALLEEG so EEGLAB can create a new one
    % itself
    AllEEG(CURRENTSET) = [];

    txt = sprintf('%i ',SelectedSet);
    txt(end) = [];
    com = sprintf('[ALLEEG, EEG, com] = pop_CombMSTemplates(%s, [%s], %i, %i, ''%s'');',inputname(1),txt,DoMeans,ShowWhenDone,MeanSetName);
    
end

% Performs element-wise computation of abs(spatial correlation) or 
% spatial correlation between matrices A and B
function corr = elementCorr(A,B, IgnorePolarity)
    % average reference
    A = A - mean(A, 1);
    B = B - mean(B, 1);

    % get correlation
    A = A./sqrt(sum(A.^2, 1));
    B = B./sqrt(sum(B.^2, 1));           
    if (IgnorePolarity) 
        corr = abs(sum(A.*B, 1));
    else 
        corr = sum(A.*B, 1);
    end
end

