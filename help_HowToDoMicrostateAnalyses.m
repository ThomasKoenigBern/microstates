% How to do microstate analyses with this EEGLAB plugin
% -----------------------------------------------------
%
% Microstate analysis is essentially a spatial pattern recognition
% procedure. This implies that you have to identify these patterns, order
% them, and assess in your data how these patterns occur. The typical 
% procedure that is followed to quantify microstates is the following:
%
% 1. Identification of predominant microstate spatial maps on the level of
% the individual datasets. This yields, for a chosen number N of microstate
% classes, a set of N spatial maps. The sequence of these maps is initially
% random. The function to do that is <a href="matlab:helpwin pop_FindMSTemplates">pop_FindMSTemplates</a>, or by calling
% that function thru the EEGLAB Tools->Microstates->Identify Microstate
% Maps menu.
%
% 2. The next step is the averaging averaging of the microstate maps across
% subjects: However, since the sequence of individual microstate maps is 
% initially random, they cannot simply be averaged or used for across 
% subject statistics. Before, the sequence of maps in the individual maps
% needs to be permutated until a maximum communality across subjects is 
% reached. Only then does it make sense to compute a grand mean, which can
% be used as a reference for the ordering of the individual microstate map
% sets. 
% To obtain such sets of grand mean microstate maps, use the function 
% <a href="matlab:helpwin pop_CombMSTemplates">pop_CombMSTemplates</a>. This function creates a new dataset with the mean
% microstate maps across subjects that maximizes the amount of variance it
% explains in the individual microstate maps. You can access this function
% also thru the EEGLAB menu under Tools->Microstates->Average microstate 
% maps across datasets.
%
% 3. You may eventually have further levels in your analysis, like you
% want to compute a grand-grand average across group mean microstate maps.
% You can do this by again using the function <a href="matlab:helpwin pop_CombMSTemplates">pop_CombMSTemplates</a>, or thru
% the menu Tools->Microstates->Compute grand mean microstate maps across
% means.
%
% 4. You end up with grandmean on the last level of you analysis. However,
% the sequence of these grandmean microstate maps is still random. But you
% may recognize some, or all of the microstate configurations known from 
% the literature in your data. You can therefore reorder the maps in the 
% grandmean. Do this by editing the  microstate maps from EEGLABs Plot menu,
% or by calling the function  <a href="matlab:helpwin pop_ShowIndMSMaps">pop_ShowIndMSMaps</a>, or using the Plot->Edit 
% microstate maps menu of EEGLAB.
%
% 5. All you have obtained so far are ordered grand mean microstate maps on
% the top level of your analysis. You can now use this grand-mean to
% quantify microstate patterns in the individual data, which takes you to
% step 6. Alternatively, you can put the lower level microstate maps into
% order now, and do the quantification of microstates based on the
% individual templates. I have no hard opinion on using grand-mean or
% individual templates. When you use the grand-mean, you measure everything
% against the same pattern, but that pattern may not perfectly fit your
% individual data. If you use individual templates, these templates
% obviously fit the individual data better, but there may be significant
% and eventually systematic variance among the microstate templates among
% subjects. So given you want to sort the individual templates, use the
% function <a href="matlab:helpwin pop_SortMSTemplates">pop_SortMSTemplates</a> to sort individual or mean  microstate maps 
% based on a template of your choice. Thru the menu, these tools are
% accessible under Tools->Microstates-> Sort... The plugin keeps track if,
% and if yes, based on which information individual and mean microstate maps
% were sorted. This information is also written to the output file, and can
% be seen when you show a set of microstate maps, and click the "Info"
% button. 
%
% 6. After all, you have microstate templates that are either an ordered
% grand-mean, or individual sets, but ordered on a grand-mean. Only at this
% point does it make sense to go back to the EEG data and quantify
% microstates based on such templates. The function that does this for you
% is <a href="matlab:helpwin pop_QuantMSTemplates">pop_QuantMSTemplates</a>, accessible thru the menu under Tools-> 
% Microstates->Quantify.... . You obtain datafiles in text or Matlab format
% that contain an extensive list of classically employed microstate
% parameters that you can continue to analyse using statistics packages.
%
%
% This is the big picture, now let's look at the details. 
%
% First of all, your data should be adequately pre-processed, which means: 
% - Periods with artifacts have been removed,
% - The data is average reference,
% - Some bandpass filter that is adequate for microstate analyses has been
%   applied. we usually choose this to be between 2-20 Hz.
%
% The clustering procedure gives you are series of choices that are useful
% to understand: 
% - You can choose between the classical k-means algorithm or the
%   assumingly better AAHC algorithm. The AAHC algorithm is faster and
%   unique, whereas the k-means may get trapped in local minima.
% - You can produce several sets of microstate maps, with a varying number
%   of classes. This is defined by the minimum and maximum number of maps.
% - Since the k-means may get trapped in local minima, it is a good idea to
%   restart it a couple of times, and retain the best solution. This is set
%   by the parameter "Number of restarts".
% - Initially, microstate clusters were only extracted based on maps at a
%   local peak of the GFP. You may, or may not choose to do so too. Maps
%   between GFP peaks have less SNR, but may contain information not
%   apparent in the peak maps.
% - Polarity reversals are typically ignored in EEG, and this is essential
%   for microstate analysis, if you don't want the states to be identified 
%   to be terminated by each reversal. So you typically chose to ignore 
%   polarity. 
%
% Apart from these data relevant choices, you may make the tool display the
% optained microstate maps and the corresponding dynamics right when
% finished. 
%
% When you have computed some microstate template maps, you may want to
% look at them. The Plot menus lets you do this. You have the option to
% switch between sets of different sizes using the "Less" and "More"
% buttons




function help_HowToDoMicrostateAnalyses()
doc help_HowToDoMicrostateAnalyses;
