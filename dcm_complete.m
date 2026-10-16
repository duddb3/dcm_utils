function [complete,tags] = dcm_complete(dcmdir,rmdups)
    % Checks whether all *.dcm files in the folder dcmdir comprise a
    % complete scan, as defined by 1) uniform spacing along the slice
    % normal direction AND 2) equal number of unique positions (i.e., that
    % there are no gaps in 4D/multi-frame images)
    
    % For cases where there is no position information (such as secondary
    % captures), the check relies on the Instance Number tag.


    % Possible things to add:
    % 1. Exceptions for certain scans that should not have uniform spacing
    % along the slice normal direction. This is the case for
    % surveys/localizers, which would probably be easy to code for; it's
    % also seems to be the case for some fetal exams where a sparse SSH is
    % used for planning. In the latter case, I don't know if there is any
    % way to determine if there are missing files.
    % 2. A check to make sure all dicoms in the folder are from the same
    % acquisition (an edge case, but I have had this issue)

    arguments
        dcmdir (1,1) string {mustBeFolder}
        rmdups (1,1) logical = false
    end

    dcms = dir(fullfile(dcmdir,'*.dcm'));
    if isempty(dcms)
        complete = false;
        tags = struct();
        return
    end

    % Get patient position of all dicom files
    tags = fast_dcm_head(dcmdir,{'InstanceNumber','ImagePositionPatient','SOPInstanceUID'});
    [~,ia] = unique({tags.SOPInstanceUID});
    if rmdups
        % I've had folders containing duplicates of files from multiple
        % attempts to send the exam (I'm guessing that because the 
        % anonymization process creates a randomized unique name, files
        % don't get overwritten)
        dups = tags(~ismember(1:length(tags),ia));
        cellfun(@delete,{dups.Filename})
    end


    tags = tags(ia);
    try
        % Get the coordinates
        C = vertcat(tags.ImagePositionPatient);
        % Sort rows by first column
        C = sortrows(C);
        % Get unique coordinates and indices
        [C,~,ic] = unique(C,'rows');
        % Check all coordinates occur the same number of times
        counts = accumarray(ic,1);
        equalcounts = all(counts==counts(1));
        % Check all unique coordinates are equally spaced within .01mm
        equalspacing = all(abs(diff(arrayfun(@(f) pdist(C(f:f+1,:)),1:size(C,1)-1)))<0.01);
        if equalcounts && equalspacing
            complete = true;
        else
            complete = false;
        end
    catch
        % If ImagePositionPatient is not found (e.g., secondary
        % capture, then we can't concatenate. Try using instance
        % numbers instead
        if max([tags.InstanceNumber])==length(tags)
            % This is not a great check, but if the max instance number is
            % equal to the number of dicom files, it is likely a complete
            % transfer
            complete = true;
        else
            complete = false;
        end
    end

end