function rd = MsMapsAndDesign4Ragu(EEGs,nMaps)

    SortingInfo = cell(numel(EEGs),1);
    for i = 1:numel(EEGs)
        SortingInfo(i) = {EEGs(i).msinfo.MSMaps(nMaps).SortedBy};
    end
    
    if numel(unique(SortingInfo)) > 1
        warning('Sorting inconsistent, this may produce false positive findings');
    end

    [rd.GroupLabels,~] = GetUniqueIdentifiers(EEGs,'group');

    [rd.conds      ,ConditionIdx ] = GetUniqueIdentifiers(EEGs,'condition');
    [SubjectLabel  ,SubjectIdx]    = GetUniqueIdentifiers(EEGs,'subject');    
    
    nSubjects   = numel(SubjectLabel);
    nConditions = numel(rd.conds);
    rd.Names    = cell(nSubjects,nConditions);
    rd.Design(:,1) = 1:nConditions;
    rd.Design(:,2) = ones(nConditions,1);

    for s = 1:nSubjects
        idx = find(SubjectIdx == s);

        for i = 1:numel(idx)
            if ~isequal(EEGs(idx(1)).group,EEGs(idx(i)).group)
                error('Group labelling inconsistent in subject %s',EEGs(idx(1)).subject);
            end
        end
        
        SubjectFeature = GetUniqueIdentifiers(EEGs(idx(1)),'group');
        
        rd.IndFeature(s,1) = find(strcmp(SubjectFeature,rd.GroupLabels),1);
        
        for c = 1:nConditions
            idx = find(SubjectIdx == s & ConditionIdx == c);
            if isempty(idx)
                warning('Condition %s for subject %s is missing, this subject will be excluded',rd.conds{c},SubjectLabel{s});
            elseif numel(idx) > 1
                warning('Condition %s for subject %s was found more than once, this subject will be excluded',rd.conds{c},SubjectLabel{s});
            else
                rd.Names(s,c) = {EEGs(idx).setname};
                SpatialResampler = MakeResampleMatrices(EEGs(idx).chanlocs,EEGs(1).chanlocs);
                rd.V(s,c,:,:) = double(EEGs(idx).msinfo.MSMaps(nMaps).Maps * SpatialResampler')';
            end
        end
    end

    GapsInTheDataMatrix = cellfun(@(x) isempty(x),rd.Names);
    SubjectsToExclude   = any(GapsInTheDataMatrix,2);
    
    rd.Names(SubjectsToExclude,:)  = [];
    rd.V(SubjectsToExclude,:,:,:)  = [];

    rd.IndName = 'Group';
    rd.strF1  = 'Condition';
    rd.TwoFactors = 0;
    rd.DeltaX = 1;
    rd.txtX = 'MS';
    rd.TimeOnset = 1;
    rd.StartFrame = 1;
    rd.EndFrame = nMaps;
    rd.axislabel = 'Class';
    rd.FreqDomain = 0;
    rd.MeanInterval = false;
    rd.ContBetween  = false;
    rd.BarGraph = true;
    rd.DoGFP    = false;
    rd.NoXing   = true;
    rd.Normalize = 2;
    rd.ContF1 = false;
    rd.Iterations = 1000;
    rd.Threshold = 0.05;

    if isempty(rd.IndFeature)
        rd.IndFeature = ones(size(rd.Names,1),1);
     end

    
    rd.MapStyle = 2;

    X = cell2mat({EEGs(1).chanlocs.X});
    Y = cell2mat({EEGs(1).chanlocs.Y});
    Z = cell2mat({EEGs(1).chanlocs.Z});

    [Theta,Phi,~] = VAcart2sph(-Y,X,Z);

    for i = 1:numel(X)
        rd.Channel(i).Name   = EEGs(1).chanlocs(i).labels;
        rd.Channel(i).Radius = 1;
        rd.Channel(i).Theta  = Theta(i);
        rd.Channel(i).Phi    = Phi(i);
    end
end


function [lbl,Assignment] = GetUniqueIdentifiers(EEGs, Identifier)
    lbl = cellfun(@(x) EEGs(x).(Identifier),num2cell(1:numel(EEGs)), 'UniformOutput',false);
    
    for i = 1:numel(lbl)
        if isnumeric(lbl{i})
            lbl(i) = {num2str(lbl{i})};
        end
    end
            
    [lbl,~,Assignment] = unique(lbl);
    lbl = lbl(:);
end
