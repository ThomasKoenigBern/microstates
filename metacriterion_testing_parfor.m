 eeglab
 
 sampleSizes = [1000 2000 4000 16000 inf];
 nRuns = 1000;
 
 for dataset = 1:24
    
    fprintf("Beginning work on dataset %d \n", dataset); 
    
    d = int2str(dataset);
    % Load dataset
    
    %EEG = pop_loadset('filename', strcat(d,'.set'), 'filepath','/project/sn_429_814/eeglab2022.0/Metacriterion_Testing_Data/');
    EEG = pop_loadset('filename', strcat(d,'.set'), 'filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\eyes_closed\\');
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'study',0); 

    % Clustering
    disp("Beginning clustering");
    tic
    [EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 4, 'MaxClasses', 10, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', inf, 'Restarts', 15, 'UseAAHC', 0, 'Normalize', 1), 0, 0);
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    disp("Finished clustering");
    toc
    
    disp("Initializing metacriteria and votes arrays");
    tic
    idx = find(EEG.setname == '/') + 1;
    setname = EEG.setname(idx:length(EEG.setname)-4);
  
    % metacriteria
    G = zeros(nRuns*length(sampleSizes), 7);
    S = zeros(nRuns*length(sampleSizes), 7);
    DB = zeros(nRuns*length(sampleSizes), 7);
    PB = zeros(nRuns*length(sampleSizes), 7);
    D = zeros(nRuns*length(sampleSizes), 7);
    KL = zeros(nRuns*length(sampleSizes), 7);
    MC1 = zeros(nRuns*length(sampleSizes), 7);

    % other criteria
    CV = zeros(nRuns*length(sampleSizes), 7);
    FVG = zeros(nRuns*length(sampleSizes), 7);
    H = zeros(nRuns*length(sampleSizes), 7);
    TW = zeros(nRuns*length(sampleSizes), 7);
    CH = zeros(nRuns*length(sampleSizes), 7);

    %GEVs
    GEV4 = zeros(nRuns*length(sampleSizes), 4);
    GEV5 = zeros(nRuns*length(sampleSizes), 5);
    GEV6 = zeros(nRuns*length(sampleSizes), 6);
    GEV7 = zeros(nRuns*length(sampleSizes), 7);
    GEV8 = zeros(nRuns*length(sampleSizes), 8);
    GEV9 = zeros(nRuns*length(sampleSizes), 9);
    GEV10 = zeros(nRuns*length(sampleSizes), 10);

    % votes
    NumSamples = zeros(nRuns*length(sampleSizes), 1);
    NumRuns = zeros(nRuns*length(sampleSizes), 1);
    Gvotes= zeros(nRuns*length(sampleSizes), 1);
    Svotes= zeros(nRuns*length(sampleSizes), 1);
    DBvotes = zeros(nRuns*length(sampleSizes), 1);
    PBvotes = zeros(nRuns*length(sampleSizes), 1);
    Dvotes= zeros(nRuns*length(sampleSizes), 1);
    KLvotes = zeros(nRuns*length(sampleSizes), 1);
    CVvotes = zeros(nRuns*length(sampleSizes), 1);
    FVGvotes = zeros(nRuns*length(sampleSizes), 1);
    Hvotes = zeros(nRuns*length(sampleSizes), 1);
    TWvotes = zeros(nRuns*length(sampleSizes), 1);
    CHvotes = zeros(nRuns*length(sampleSizes), 1);
    MC2votes = zeros(nRuns*length(sampleSizes), 1);
    disp("Done initializing metacriteria arrays");
    toc
    
    tic

    parfor i = 1:nRuns*length(sampleSizes)
        if (i == 5000)
            s = 5;
        else
            s = floor(i/nRuns) + 1;		% index of sampleSizes to use
        end
        fprintf("Beginning calculating metacriteria for %d samples\n", sampleSizes(s));
        
        [metacriteria, criteria, GEVs, mcVotes, ~] = clustNumSelection(ALLEEG, EEG, CURRENTSET, sampleSizes(s));

        % metacriteria
        G(i, :) = gamma;
        S(i, :) = metacriteria.S;
        DB(i, :) = metacriteria.DB;
        PB(i, :) = metacriteria.PB;
        D(i , :) = metacriteria.D;
        KL(i, :) = metacriteria.KL;
        MC1(i, :) = metacriteria.MC1;        
        
        % extra criteria
        CV (i, :) = criteria.CV;
        FVG(i, :) = criteria.FVG;
        H(i  , :) = criteria.H;
        TW (i, :) = criteria.TW;
        CH (i, :) = criteria.CH;
        
        % GEVs
        GEV4(i, :) =  GEVs{1};
        GEV5 (i, :) = GEVs{2};
        GEV6 (i, :) = GEVs{3};
        GEV7 (i, :) = GEVs{4};
        GEV8 (i, :) = GEVs{5};
        GEV9 (i, :) = GEVs{6};
        GEV10(i, :) = GEVs{7};

        % votes
        Gvotes (i) = mcVotes.G;
        Svotes (i) = mcVotes.S;
        DBvotes(i) = mcVotes.DB;
        PBvotes(i) = mcVotes.PB;
        Dvotes (i) = mcVotes.D;
        KLvotes(i) = mcVotes.KL;
        CVvotes(i) = mcVotes.CV;
        FVGvotes(i) = mcVotes.FVG;
        Hvotes(i) = mcVotes.H;
        TWvotes(i) = mcVotes.TW;
        CHvotes(i) = mcVotes.CH;
        MC2votes(i) = mcVotes.MC2;
    
        display = sprintf('run #: %d', i);
        disp(display)

        fprintf("Done calculating metacriteria for all %d samples\n", sampleSizes(s));
        toc
    end
    
    % write csvs with raw normalized criterion values, one for each cluster
    % solution
    fprintf("Writing csvs for dataset %d \n", dataset); 
    tic

    names = [{'run_no'}; {'sample_size'}; {'G'}; {'S'}; {'DB'}; {'PB'}; {'D'}; {'KL'}; {'MC1'};
        {'CV'}; {'FVG'}; {'H'}; {'TW'}; {'CH'}];

    runs = 1:nRuns;
    runs = repmat(runs, 1, length(sampleSizes))';
    samples = zeros(nRuns*length(sampleSizes), 1);

    for i = 1:length(sampleSizes)
        sampleSize = sampleSizes(i);
        samples((i-1)*nRuns+1:i*nRuns) = sampleSize;
    end

    tbl4Clust = table(runs, samples, G(:,1), S(:,1), DB(:,1), PB(:,1), D(:,1), KL(:,1), MC1(:, 1), CV(:,1), FVG(:,1), H(:,1), TW(:,1), CH(:,1), GEV4(:, 1), GEV4(:, 2), GEV4(:, 3), GEV4(:, 4));
    tbl5Clust = table(runs, samples, G(:,2), S(:,2), DB(:,2), PB(:,2), D(:,2), KL(:,2), MC1(:, 2), CV(:,2), FVG(:,2), H(:,2), TW(:,2), CH(:,2), GEV5(:, 1), GEV5(:, 2), GEV5(:, 3), GEV5(:, 4), GEV5(:, 5));
    tbl6Clust = table(runs, samples, G(:,3), S(:,3), DB(:,3), PB(:,3), D(:,3), KL(:,3), MC1(:, 3), CV(:,3), FVG(:,3), H(:,3), TW(:,3), CH(:,3), GEV6(:, 1), GEV6(:, 2), GEV6(:, 3), GEV6(:, 4), GEV6(:, 5), GEV6(:, 6));
    tbl7Clust = table(runs, samples, G(:,4), S(:,4), DB(:,4), PB(:,4), D(:,4), KL(:,4), MC1(:, 4), CV(:,4), FVG(:,4), H(:,4), TW(:,4), CH(:,4), GEV7(:, 1), GEV7(:, 2), GEV7(:, 3), GEV7(:, 4), GEV7(:, 5), GEV7(:, 6), GEV7(:, 7));
    tbl8Clust = table(runs, samples, G(:,5), S(:,5), DB(:,5), PB(:,5), D(:,5), KL(:,5), MC1(:, 5), CV(:,5), FVG(:,5), H(:,5), TW(:,5), CH(:,5), GEV8(:, 1), GEV8(:, 2), GEV8(:, 3), GEV8(:, 4), GEV8(:, 5), GEV8(:, 6), GEV8(:, 7), GEV8(:, 8));
    tbl9Clust = table(runs, samples, G(:,6), S(:,6), DB(:,6), PB(:,6), D(:,6), KL(:,6), MC1(:, 6), CV(:,6), FVG(:,6), H(:,6), TW(:,6), CH(:,6), GEV9(:, 1), GEV9(:, 2), GEV9(:, 3), GEV9(:, 4), GEV9(:, 5), GEV9(:, 6), GEV9(:, 7), GEV9(:, 8), GEV9(:, 9));
    tbl10Clust = table(runs, samples, G(:,7), S(:,7), DB(:,7), PB(:,7), D(:,7), KL(:,7), MC1(:, 7), CV(:,7), FVG(:,7), H(:,7), TW(:,7), CH(:,7), GEV10(:, 1), GEV10(:, 2), GEV10(:, 3), GEV10(:, 4), GEV10(:, 5), GEV10(:, 6), GEV10(:, 7), GEV10(:, 8), GEV10(:, 9), GEV10(:, 10));

    tbl4Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}];
    tbl5Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}];
    tbl6Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}; {'GEV_F'}];
    tbl7Clust.Properties.VariableNames = [names; {'GEV_A'} ; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}; {'GEV_F'}; {'GEV_G'}];
    tbl8Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}; {'GEV_F'}; {'GEV_G'}; {'GEV_H'}];
    tbl9Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}; {'GEV_F'}; {'GEV_G'}; {'GEV_H'}; {'GEV_I'}];
    tbl10Clust.Properties.VariableNames = [names; {'GEV_A'}; {'GEV_B'}; {'GEV_C'}; {'GEV_D'}; {'GEV_E'}; {'GEV_F'}; {'GEV_G'}; {'GEV_H'}; {'GEV_I'}; {'GEV_J'}];

    mkdir(setname);
    cd(setname);
    writetable(tbl4Clust, strcat(setname, '_4clusters.csv'));
    writetable(tbl5Clust, strcat(setname, '_5clusters.csv'));
    writetable(tbl6Clust, strcat(setname, '_6clusters.csv'));
    writetable(tbl7Clust, strcat(setname, '_7clusters.csv'));
    writetable(tbl8Clust, strcat(setname, '_8clusters.csv'));
    writetable(tbl9Clust, strcat(setname, '_9clusters.csv'));
    writetable(tbl10Clust, strcat(setname, '_10clusters.csv'));

    % write csv with votes for each criterion and the median metacriterion
    % (calculated using the 6 metacriteria
    tblVotes = table(runs, samples, Gvotes, Svotes, DBvotes, PBvotes, Dvotes, KLvotes, CVvotes, FVGvotes, Hvotes, TWvotes, CHvotes, MC2votes);
    names = [{'run_no'}; {'sample_size'}; {'Gvotes'}; {'Svotes'}; {'DBvotes'}; {'PBvotes'}; {'Dvotes'}; {'KLvotes'};
        {'CVvotes'}; {'FVGvotes'}; {'Hvotes'}; {'TWvotes'}; {'CHvotes'}' {'MC2votes'}];
    tblVotes.Properties.VariableNames = names;
    writetable(tblVotes, strcat(setname, '_votes.csv'));

    fprintf("Done writing csvs for dataset %d \n", dataset); 
    toc

    % edges = [3.5 4.5 5.5 6.5 7.5 8.5 9.5 10.5];
    % f = figure;
    % tiledlayout(3,2);
    % nexttile
    % histogram(S, edges);
    % title('Silhouette')
    % nexttile
    % histogram(DB, edges);
    % title('Davies-Bouldin')
    % nexttile
    % histogram(PB, edges);
    % title('Point-Biserial')
    % nexttile
    % histogram(D, edges);
    % title('Dunn')
    % nexttile
    % histogram(KL, edges);
    % title('Krzanowski-Lai')
    % nexttile
    % histogram(MC, edges);
    % title('Metacriterion')
    % 
    % saveas(f, '1000samples.pdf');

    %eeglab redraw
end
