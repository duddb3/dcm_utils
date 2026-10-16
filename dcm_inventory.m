function T = dcm_inventory(root,pt_str,ses_str,scn_inc,scn_exc,meta)
    % This function produces a table T containing information about the
    % imaging data contained in a directory. The directory must be
    % organized in a standard DICOM hierarchy:
    %     root
    %       patient
    %         session
    %           scan
    % Given the directory "root", return table "T" that contain columns:
    %     ID: folders in root containing "pt_str"
    %     Session: folders in the patient folders matching "ses_str"
    %     Scans: folders in the session folders matching "scn_str"
    % The table is tall, with 1 row per scan found. If "meta" is specified,
    % dicom metadata is read from the first dicom file in each scan folder
    % and placed in the table as well. "meta" must be a cell array
    % containing names or group-element tags, e.g.:
    %     {'EchoTime','(0010,0010)'}
    
    arguments
        root (1,1) string {mustBeFolder}
        pt_str {mustBeTextScalar} = ""
        ses_str {mustBeTextScalar} = ""
        scn_inc (1,:) string = ""
        scn_exc (1,:) string = ""
        meta cell = {}
    end

    rmdups = true;

    if isempty(pt_str)
        pt_str = "*";
    elseif strcmp(pt_str,'**')
        % Recursive wildcard, don't change
    else
        pt_str = "*" + pt_str + "*";
    end
    if isempty(ses_str)
        ses_str = "*";
    elseif strcmp(ses_str,'**')
        % Recursive wildcard, don't change
    else
        ses_str = "*" + ses_str + "*";
    end
    
    % Find all matching items
    scns = [];
    for s=1:length(scn_inc)
        if isempty(scn_inc(s))
            incs = "*";
        else
            incs = "*" + scn_inc(s) + "*";
        end
        scns = cat(1,scns,dir(fullfile(root,pt_str,ses_str,incs)));
    end
    % Remove exclusion strings from list
    if ~isempty(scn_exc) && all(~strcmp(scn_exc,""))
        scns(contains({scns.name},scn_exc))=[];
    end
    % Remove files from list
    scns(~[scns.isdir]) = [];
    if isempty(scns)
        T = [];
        fprintf(2,'No matching scans found\n')
        return
    end
    % Sort by folder
    [~,o] = sort({scns.folder});
    scns = scns(o);

    [pths,sessions] = fileparts({scns.folder});
    [~,pts] = fileparts(pths);
    T = table(pts',sessions',{scns.name}',...
        'VariableNames',{'ID','Session','ScanName'});
    
    completeTransfer = false(height(T),1);
    if ~isempty(meta)
        metadata = cell2struct(cell(1,length(meta)+1),cellstr(["Filename",meta]),2);
    end
    parfor n=1:length(scns)
        scndir = fullfile(scns(n).folder,scns(n).name);
        completeTransfer(n) = dcm_complete(scndir);
        

        if ~isempty(meta)
            % temp = fast_dcm_head(scndir,meta,1);
            metadata(n) = fast_dcm_head(scndir,meta,1);
        end
    end
    T.CompleteTransfer = completeTransfer;
    if ~isempty(meta)
        metadata = struct2table(metadata);
        T = cat(2,T,metadata);
    end

    

end