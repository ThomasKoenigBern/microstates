function [success,err] = SaveStructToR(dat,FileName)

    dat = dat(:);
    
    SingleFieldsToWrite = {'DataSet','Subject','Group','Condition','Template','ExpVar','SortInfo','TotalTime'};
    MultipleFieldsToWrite = {'Duration','Occurrence','Contribution','MeanGFP'};
    
    
    nObs = numel(dat);
    nClasses = size(dat(1).('Duration'),2);
    
    [fid,err] = fopen(FileName,'wt');

    if fid == -1
        success = false;
        return
    end
    

    
    for i = 1: numel(SingleFieldsToWrite)
        if i > 1
            fprintf(fid,';');
        end
        fprintf(fid,'%s',SingleFieldsToWrite{i});
    end
    fprintf(fid,';Class');

    for i = 1: numel(MultipleFieldsToWrite)
        fprintf(fid,';%s',MultipleFieldsToWrite{i});
    end
    fprintf(fid,'\n');
    % End of the header
    
    for j = 1:numel(dat)
        for k = 1:nClasses
            for i = 1: numel(SingleFieldsToWrite)
                if i > 1
                    fprintf(fid,';');
                end
                if ischar(dat(j).(SingleFieldsToWrite{i}))
                    fprintf(fid,'%s',dat(j).(SingleFieldsToWrite{i}));
                else
                    fprintf(fid,'%5.5f',dat(j).(SingleFieldsToWrite{i}));
                end
            end
            fprintf(fid,';%i',k);

            for i = 1: numel(MultipleFieldsToWrite)
                fprintf(fid,';%5.5f',dat(j).(MultipleFieldsToWrite{i})(k));
            end
            fprintf(fid,'\n');
        end
    end
            
            
%     fprintf(fid,';%s',MultipleFieldsToWrite{i});
%         if ischar(dat(1).(names{i}))
%             s = 1;
%         else
%             s =  size(dat(1).(names{i}));
%         end
%         if size(s) > 2
%             success = false;
%             err = 'More than 2D arrays not supported';
%             return
%         end
%         if min(s) == 1
%             x1 = max(s);
%             x2 = 1;
%         else
%             x1 = s(1);
%             x2 = s(2);
%         end
%     
%         if x1 == 1
%             outnames{idx} = names{i}; %#ok<*AGROW>
%             for n = 1:nObs
%                 outfields{n,idx} = dat(n).(names{i});
%             end
%             idx = idx + 1;
%         else
%             if x2 == 1
%                 for j = 1:x1
%                     outnames{idx+j-1} = sprintf('%s_%i',names{i},j);
%                 end
%                 for n = 1:nObs
%                     tmp = dat(n).(names{i}); 
%                     for j = 1:x1
%                         outfields{n,idx+j-1} = tmp(j);
%                     end
%                 end
%                 idx = idx + x1;
%             else
%                 for j = 1:x1
%                     for k = 1:x2
%                         outnames{idx+x2 * (j-1) + k -1} = sprintf('%s_%i->%i',names{i},j,k);
%                     end
%                 end
%                
%                 for n = 1:nObs
%                     tmp = dat(n).(names{i})'; 
%                     tmp = tmp(:);
%                     for j = 1:numel(tmp);
%                        outfields{n,idx+j-1} = tmp(j);
%                     end
%                 end
%                 idx = idx + numel(tmp);
%             end
%         end    
%     end
%     
%     
%     for n = 1:numel(outnames)
%         if n > 1
%             fprintf(fid,';');
%         end
%         fprintf(fid,'%s',outnames{n});
%     end
%     
%     for c = 1:size(outfields,1)
%         for n = 1:size(outfields,2)
%             if n == 1
%                 fprintf(fid,'\n');
%             else
%                 fprintf(fid,'%s',Delimiter);
%             end
%             fprintf(fid,'%s',outfields{c,n});
%         end
%     end
%     fclose(fid);
%     success = true;
end
