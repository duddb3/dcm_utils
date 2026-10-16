function [complete,tags] = dcm_complete(dcmdir,rmdups)
    % Checks whether all *.dcm files in the folder dcmdir comprise a
    % complete scan, as defined by 1) uniform spacing along the slice
    % normal direction AND 2) equal number of unique positions (i.e., that
    % there are no gaps in 4D/multi-frame images). This will correctly 
    % "pass" if the folder is missing uniformly spaced slices (e.g., if all
    % odd-numbered slices are missing), but that seems like an exceedingly 
    % unlikely scenario. This also won't catch missing data if the missing
    % data are at the beginning/end of the slice normal direction.
    
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
    tags = fast_dcm_head(dcmdir,{'InstanceNumber','ImagePositionPatient','ImageOrientationPatient','SOPInstanceUID'});
    [~,ia] = unique({tags.SOPInstanceUID},'stable');
    if rmdups
        % I've had folders containing duplicates of files from multiple
        % attempts to send the exam (I'm guessing that because the 
        % anonymization process creates a randomized unique name, files
        % don't get overwritten)
        dups = tags(~ismember(1:length(tags),ia));
        for k = 1:numel(dups)
            try
                delete(dups(k).Filename);
            catch
                fprintf(sprintf('Warning: could not delete duplicate file %s:',dups(k).Filename));
            end
        end
    end


    tags = tags(ia);
    try
        % Get the coordinates
        C = vertcat(tags.ImagePositionPatient);
        % Get the slice normal
        IOP = tags(1).ImageOrientationPatient(:);
        rowdir = IOP(1:3);
        coldir = IOP(4:6);
        normal = cross(rowdir,coldir);
        normal = normal / norm(normal);
        % Project coordinates onto slice normal
        d = C*normal;
        % Find & sort unique coordinates (to nearest 0.01mm)
        [ud,~,ic] = unique(round(d,2));
        % Check all coordinates occur the same number of times
        counts = accumarray(ic,1);
        equalcounts = all(counts==counts(1));
        % Check all unique coordinates are equally spaced to within 0.01mm
        if isscalar(ud)
            % If only position (single 2D image)
            equalspacing = true;
        else
            spacing = diff(ud);
            equalspacing = all(abs(spacing - spacing(1))<0.01);
        end
        if equalcounts && equalspacing
            complete = true;
        else
            complete = false;
        end
    catch
        % If ImagePositionPatient is not found (e.g., secondary
        % capture) then we can't concatenate. Try using instance
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